-- 已部署项目执行本文件一次；可重复执行。先迁移数据库，再发布前端。
-- 延续项目现有自定义登录 / 开放 RLS 模型，actor_id 是业务归属校验，
-- 不是 Supabase Auth 身份认证。所有 RPC 为 SECURITY INVOKER。
BEGIN;

CREATE TABLE IF NOT EXISTS point_earnings (
  source_id TEXT PRIMARY KEY,
  student_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  teacher_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  points INTEGER NOT NULL CHECK (points > 0),
  reason TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS point_earnings_week_idx ON point_earnings(teacher_id, created_at, student_id);
ALTER TABLE point_earnings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "读取积分收入" ON point_earnings;
DROP POLICY IF EXISTS "记录积分收入" ON point_earnings;
CREATE POLICY "读取积分收入" ON point_earnings FOR SELECT USING (true);
CREATE POLICY "记录积分收入" ON point_earnings FOR INSERT WITH CHECK (true);

CREATE TABLE IF NOT EXISTS feeding_events (
  request_id UUID PRIMARY KEY,
  actor_id UUID NOT NULL,
  student_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  pet_id UUID NOT NULL REFERENCES pets(id) ON DELETE CASCADE,
  action TEXT NOT NULL,
  result JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE feeding_events ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "读取喂食记录" ON feeding_events;
DROP POLICY IF EXISTS "记录喂食结果" ON feeding_events;
CREATE POLICY "读取喂食记录" ON feeding_events FOR SELECT USING (true);
CREATE POLICY "记录喂食结果" ON feeding_events FOR INSERT WITH CHECK (true);

-- 仅补入有原始记录的任务奖励，不用余额或当前日记价格猜测历史收入。
INSERT INTO point_earnings(source_id, student_id, teacher_id, points, reason, created_at)
SELECT 'task:' || c.id, c.student_id, c.awarded_by, c.points,
       COALESCE(t.name, '任务奖励'), c.created_at
FROM task_completions c JOIN profiles p ON p.id = c.student_id
LEFT JOIN tasks t ON t.id = c.task_id
WHERE c.points > 0
ON CONFLICT (source_id) DO NOTHING;

CREATE OR REPLACE FUNCTION feed_pet(
  p_actor_id UUID, p_student_id UUID, p_pet_id UUID, p_action TEXT, p_request_id UUID
) RETURNS JSONB LANGUAGE plpgsql SECURITY INVOKER SET search_path = public AS $$
DECLARE
  s profiles%ROWTYPE;
  p pets%ROWTYPE;
  e feeding_events%ROWTYPE;
  price INTEGER;
  gain INTEGER;
  food_xp INTEGER;
  prices JSONB;
  old_level INTEGER;
  result JSONB;
  thresholds INTEGER[] := ARRAY[0,20,50,90,140,200,275,365,470,590,730,890,1070,1270,1495,1745,2025,2335,2675,3050];
BEGIN
  IF p_request_id IS NULL OR p_actor_id IS NULL OR p_student_id IS NULL OR p_pet_id IS NULL OR p_action IS NULL OR p_action NOT IN ('basic','nice','luxury') THEN
    RAISE EXCEPTION '无效的喂食请求';
  END IF;
  -- 固定锁顺序：学生 -> 宠物。同一学生的多只宠物也共享余额锁。
  SELECT * INTO s FROM profiles WHERE id = p_student_id AND role = 'student' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION '学生不存在'; END IF;
  IF p_actor_id IS NULL OR NOT (p_actor_id = s.id OR EXISTS (
    SELECT 1 FROM profiles a WHERE a.id = p_actor_id AND a.role = 'teacher' AND a.id = s.teacher_id
  )) THEN RAISE EXCEPTION '只能照顾本人或本班学生的宠物'; END IF;

  SELECT * INTO e FROM feeding_events WHERE request_id = p_request_id;
  IF FOUND THEN
    IF e.actor_id IS DISTINCT FROM p_actor_id OR e.student_id IS DISTINCT FROM p_student_id OR e.pet_id IS DISTINCT FROM p_pet_id OR e.action IS DISTINCT FROM p_action THEN
      RAISE EXCEPTION '请求编号已用于其他操作';
    END IF;
    RETURN e.result;
  END IF;
  SELECT * INTO p FROM pets WHERE id = p_pet_id AND owner_id = s.id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION '宠物不存在或不属于该学生'; END IF;
  SELECT value INTO prices FROM settings WHERE key = 'action_costs';
  price := COALESCE((prices ->> p_action)::INTEGER, CASE p_action WHEN 'basic' THEN 5 WHEN 'nice' THEN 10 ELSE 20 END);
  IF price < 0 THEN RAISE EXCEPTION '喂食价格配置无效'; END IF;
  IF COALESCE(s.points, 0) < price THEN RAISE EXCEPTION '积分不足，需要 % 积分', price; END IF;
  gain := CASE p_action WHEN 'basic' THEN 25 WHEN 'nice' THEN 55 ELSE 100 END;
  food_xp := CASE p_action WHEN 'basic' THEN 8 WHEN 'nice' THEN 18 ELSE 40 END;
  old_level := COALESCE(p.level, 1);
  p.hunger := LEAST(100, GREATEST(0, COALESCE(p.hunger,0) - floor(
    floor(GREATEST(0, extract(epoch FROM (now() - COALESCE(p.last_fed_at,p.created_at,now())))) / 3600) * 1.5
  )::INTEGER) + gain);
  p.xp := COALESCE(p.xp, 0) + food_xp;
  SELECT count(*)::INTEGER INTO p.level FROM unnest(thresholds) AS threshold WHERE threshold <= p.xp;
  UPDATE profiles SET points = COALESCE(points,0) - price WHERE id = s.id RETURNING * INTO s;
  UPDATE pets SET hunger = p.hunger, xp = p.xp, level = p.level, last_fed_at = now()
    WHERE id = p.id RETURNING * INTO p;
  result := jsonb_build_object('points',s.points,'pet',to_jsonb(p),'cost',price,'leveledUp',p.level > old_level);
  INSERT INTO feeding_events(request_id,actor_id,student_id,pet_id,action,result)
    VALUES(p_request_id,p_actor_id,s.id,p.id,p_action,result);
  RETURN result;
END $$;

CREATE OR REPLACE FUNCTION award_task_points(
  p_actor_id UUID, p_student_id UUID, p_task_id UUID, p_request_id UUID
) RETURNS JSONB LANGUAGE plpgsql SECURITY INVOKER SET search_path = public AS $$
DECLARE s profiles%ROWTYPE; t tasks%ROWTYPE; c task_completions%ROWTYPE;
BEGIN
  IF p_request_id IS NULL THEN RAISE EXCEPTION '缺少请求编号'; END IF;
  SELECT * INTO s FROM profiles WHERE id = p_student_id AND role = 'student' FOR UPDATE;
  IF NOT FOUND OR p_actor_id IS NULL OR s.teacher_id IS DISTINCT FROM p_actor_id
    OR NOT EXISTS(SELECT 1 FROM profiles WHERE id = p_actor_id AND role = 'teacher') THEN
    RAISE EXCEPTION '只能给本班学生发放积分';
  END IF;
  SELECT * INTO c FROM task_completions WHERE id = p_request_id;
  IF FOUND THEN
    IF c.student_id IS DISTINCT FROM s.id OR c.awarded_by IS DISTINCT FROM p_actor_id OR c.task_id IS DISTINCT FROM p_task_id THEN
      RAISE EXCEPTION '请求编号已用于其他操作';
    END IF;
    RETURN jsonb_build_object('points',c.points,'balance',s.points);
  END IF;
  SELECT * INTO t FROM tasks WHERE id = p_task_id AND created_by = p_actor_id AND is_active = true FOR SHARE;
  IF NOT FOUND OR t.points <= 0 THEN RAISE EXCEPTION '任务已停用或奖励积分无效'; END IF;
  INSERT INTO task_completions(id,task_id,student_id,awarded_by,points)
    VALUES(p_request_id,t.id,s.id,p_actor_id,t.points);
  UPDATE profiles SET points = COALESCE(points,0) + t.points WHERE id = s.id RETURNING * INTO s;
  INSERT INTO point_earnings(source_id,student_id,teacher_id,points,reason)
    VALUES('task:' || p_request_id,s.id,p_actor_id,t.points,t.name);
  RETURN jsonb_build_object('points',t.points,'balance',s.points);
END $$;

-- 日记发布、每日首篇奖励和流水同事务，避免与喂食并发时覆盖余额。
CREATE OR REPLACE FUNCTION publish_diary(
  p_actor_id UUID, p_pet_id UUID, p_entry JSONB, p_request_id UUID
) RETURNS JSONB LANGUAGE plpgsql SECURITY INVOKER SET search_path = public AS $$
DECLARE s profiles%ROWTYPE; d diary_entries%ROWTYPE; reward INTEGER := 0; day_start TIMESTAMPTZ;
BEGIN
  SELECT * INTO s FROM profiles WHERE id = p_actor_id AND role = 'student' FOR UPDATE;
  IF NOT FOUND OR p_request_id IS NULL THEN RAISE EXCEPTION '无效的学生或发布请求'; END IF;
  SELECT * INTO d FROM diary_entries WHERE id = p_request_id;
  IF FOUND THEN
    IF d.owner_id IS DISTINCT FROM s.id OR d.pet_id IS DISTINCT FROM p_pet_id THEN RAISE EXCEPTION '请求编号已用于其他操作'; END IF;
    SELECT COALESCE(sum(points),0)::INTEGER INTO reward FROM point_earnings WHERE source_id = 'diary:' || d.id;
    RETURN jsonb_build_object('entry',to_jsonb(d),'points',s.points,'reward',reward);
  END IF;
  IF NOT EXISTS(SELECT 1 FROM pets WHERE id = p_pet_id AND owner_id = s.id) THEN
    RAISE EXCEPTION '宠物不存在或不属于该学生';
  END IF;
  IF trim(COALESCE(p_entry->>'title','')) = '' OR trim(COALESCE(p_entry->>'content','')) = '' THEN
    RAISE EXCEPTION '请填写日记标题和内容';
  END IF;
  day_start := date_trunc('day',now() AT TIME ZONE 'Asia/Shanghai') AT TIME ZONE 'Asia/Shanghai';
  IF NOT EXISTS(SELECT 1 FROM diary_entries WHERE owner_id = s.id AND created_at >= day_start)
    AND NOT EXISTS(SELECT 1 FROM point_earnings WHERE student_id = s.id AND source_id LIKE 'diary:%' AND created_at >= day_start) THEN
    SELECT COALESCE((value->>'points')::INTEGER,5) INTO reward FROM settings WHERE key = 'diary_points';
    reward := GREATEST(0,COALESCE(reward,5));
  END IF;
  INSERT INTO diary_entries(id,owner_id,pet_id,title,content,image_url,mood,is_public)
    VALUES(p_request_id,s.id,p_pet_id,p_entry->>'title',p_entry->>'content',p_entry->>'image_url',
      COALESCE(p_entry->>'mood','happy'),COALESCE((p_entry->>'is_public')::BOOLEAN,true)) RETURNING * INTO d;
  IF reward > 0 THEN
    UPDATE profiles SET points = COALESCE(points,0) + reward WHERE id = s.id RETURNING * INTO s;
    INSERT INTO point_earnings(source_id,student_id,teacher_id,points,reason)
      VALUES('diary:' || d.id,s.id,s.teacher_id,reward,'每日首篇日记');
  END IF;
  RETURN jsonb_build_object('entry',to_jsonb(d),'points',s.points,'reward',reward);
END $$;

CREATE OR REPLACE FUNCTION weekly_leaderboard(p_teacher_id UUID)
RETURNS JSONB LANGUAGE sql STABLE SECURITY INVOKER SET search_path = public AS $$
  WITH period AS (
    SELECT date_trunc('week',now() AT TIME ZONE 'Asia/Shanghai') AT TIME ZONE 'Asia/Shanghai' AS start_at
  ), totals AS (
    SELECT p.id,p.username,COALESCE(sum(e.points),0) AS points
    FROM profiles p CROSS JOIN period w
    LEFT JOIN point_earnings e ON e.student_id = p.id AND e.teacher_id = p_teacher_id
      AND e.created_at >= w.start_at AND e.created_at < w.start_at + interval '7 days'
    WHERE p.teacher_id = p_teacher_id AND p.role = 'student'
    GROUP BY p.id,p.username
  ), ranked AS (
    SELECT t.*,CASE WHEN t.points > 0 THEN row_number() OVER (ORDER BY t.points DESC,t.username,t.id) ELSE NULL END AS rank,
      COALESCE(pet.level,0) AS pet_level,COALESCE(pet.name,'未领养') AS pet_name
    FROM totals t LEFT JOIN LATERAL (
      SELECT name,level FROM pets WHERE owner_id = t.id ORDER BY level DESC,created_at,id LIMIT 1
    ) pet ON true
  ) SELECT jsonb_build_object('weekStart',w.start_at,'weekEnd',w.start_at + interval '7 days',
    'entries',COALESCE((SELECT jsonb_agg(to_jsonb(r) ORDER BY r.points DESC,r.username,r.id) FROM ranked r),'[]'::JSONB))
  FROM period w;
$$;

GRANT SELECT, INSERT ON point_earnings, feeding_events TO anon, authenticated;
GRANT EXECUTE ON FUNCTION feed_pet(UUID,UUID,UUID,TEXT,UUID),
  award_task_points(UUID,UUID,UUID,UUID),publish_diary(UUID,UUID,JSONB,UUID),weekly_leaderboard(UUID) TO anon, authenticated;
COMMIT;
