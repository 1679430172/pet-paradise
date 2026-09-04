-- ==========================================
-- 班级宠物乐园（pet-paradise）— 全新部署 SQL
-- 在 Supabase Dashboard → SQL Editor 整段执行一次即可
-- 不依赖 Supabase Auth，使用自定义用户名/密码（SHA-256 + salt）
-- ==========================================

-- ============== 1. 用户资料表 ==============
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  username TEXT NOT NULL UNIQUE,
  password TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'student',   -- 'student' | 'teacher'
  points INTEGER DEFAULT 0,                -- 学生积分余额
  avatar_url TEXT,
  class_name TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Multi-teacher migration: students belong to a teacher; class_name remains
-- the human-readable class label. Safe to run against an existing database.
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS teacher_id UUID REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_admin BOOLEAN NOT NULL DEFAULT false;
CREATE INDEX IF NOT EXISTS profiles_teacher_id_idx ON profiles(teacher_id);

-- Student names only need to be unique inside the same teacher's class.
-- Teacher/admin account names remain globally unique among teacher accounts.
ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_username_key;
CREATE UNIQUE INDEX IF NOT EXISTS profiles_teacher_username_unique
  ON profiles(username) WHERE role = 'teacher';
CREATE UNIQUE INDEX IF NOT EXISTS profiles_student_class_username_unique
  ON profiles(teacher_id, username) WHERE role = 'student';

-- ============== 2. 宠物表（支持一人多宠物） ==============
CREATE TABLE IF NOT EXISTS pets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  species TEXT NOT NULL,                   -- 与 public/assets/pets/{species} 文件夹名一致
  appearance JSONB DEFAULT '{}',           -- { color, accessory, background }
  level INTEGER DEFAULT 1,                 -- 1 ~ 20
  xp INTEGER DEFAULT 0,
  hunger INTEGER DEFAULT 100,              -- 饱食度（唯一活跃状态）
  happiness INTEGER DEFAULT 100,           -- 历史字段，保留以兼容旧数据，前端不再使用
  cleanliness INTEGER DEFAULT 100,         -- 历史字段，保留以兼容旧数据，前端不再使用
  last_fed_at TIMESTAMPTZ,
  last_played_at TIMESTAMPTZ,              -- 历史字段，保留以兼容旧数据
  last_cleaned_at TIMESTAMPTZ,             -- 历史字段，保留以兼容旧数据
  badges JSONB DEFAULT '["first_pet"]',
  created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS pets_owner_id_idx ON pets(owner_id);

-- ============== 3. 日记表 ==============
CREATE TABLE IF NOT EXISTS diary_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  pet_id UUID REFERENCES pets(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  image_url TEXT,
  mood TEXT DEFAULT 'happy',
  is_public BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ============== 4. 点赞表 ==============
CREATE TABLE IF NOT EXISTS likes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  diary_id UUID REFERENCES diary_entries(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, diary_id)
);

-- ============== 5. 系统配置表 ==============
CREATE TABLE IF NOT EXISTS settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key TEXT UNIQUE NOT NULL,
  value JSONB NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 三档喂食的默认积分消耗
INSERT INTO settings (key, value)
VALUES ('action_costs', '{"basic": 5, "nice": 10, "luxury": 20}')
ON CONFLICT (key) DO NOTHING;

-- 每日首篇日记的积分奖励
INSERT INTO settings (key, value)
VALUES ('diary_points', '{"points": 5}')
ON CONFLICT (key) DO NOTHING;

-- 是否允许学生从登录页自行注册账号
INSERT INTO settings (key, value)
VALUES ('registration_enabled', '{"enabled": true}')
ON CONFLICT (key) DO NOTHING;

-- ============== 6. 任务定义表 ==============
CREATE TABLE IF NOT EXISTS tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  points INTEGER NOT NULL,
  is_active BOOLEAN DEFAULT true,
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ============== 7. 任务完成记录表 ==============
CREATE TABLE IF NOT EXISTS task_completions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID REFERENCES tasks(id),
  student_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  awarded_by UUID REFERENCES profiles(id),
  points INTEGER NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ==========================================
-- RLS 策略（开放式，因为不使用 Supabase Auth）
-- ==========================================

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "允许查看资料" ON profiles;
DROP POLICY IF EXISTS "允许插入资料" ON profiles;
DROP POLICY IF EXISTS "允许更新资料" ON profiles;
DROP POLICY IF EXISTS "允许删除学生" ON profiles;
CREATE POLICY "允许查看资料"     ON profiles FOR SELECT USING (true);
CREATE POLICY "允许插入资料"     ON profiles FOR INSERT WITH CHECK (true);
CREATE POLICY "允许更新资料"     ON profiles FOR UPDATE USING (true);
CREATE POLICY "允许删除学生"     ON profiles FOR DELETE USING (true);

ALTER TABLE pets ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "允许查看宠物" ON pets;
DROP POLICY IF EXISTS "允许创建宠物" ON pets;
DROP POLICY IF EXISTS "允许更新宠物" ON pets;
DROP POLICY IF EXISTS "允许删除宠物" ON pets;
CREATE POLICY "允许查看宠物"     ON pets FOR SELECT USING (true);
CREATE POLICY "允许创建宠物"     ON pets FOR INSERT WITH CHECK (true);
CREATE POLICY "允许更新宠物"     ON pets FOR UPDATE USING (true);
CREATE POLICY "允许删除宠物"     ON pets FOR DELETE USING (true);

ALTER TABLE diary_entries ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "允许查看日记" ON diary_entries;
DROP POLICY IF EXISTS "允许创建日记" ON diary_entries;
DROP POLICY IF EXISTS "允许更新日记" ON diary_entries;
DROP POLICY IF EXISTS "允许删除日记" ON diary_entries;
CREATE POLICY "允许查看日记"     ON diary_entries FOR SELECT USING (true);
CREATE POLICY "允许创建日记"     ON diary_entries FOR INSERT WITH CHECK (true);
CREATE POLICY "允许更新日记"     ON diary_entries FOR UPDATE USING (true);
CREATE POLICY "允许删除日记"     ON diary_entries FOR DELETE USING (true);

ALTER TABLE likes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "允许查看点赞" ON likes;
DROP POLICY IF EXISTS "允许点赞" ON likes;
DROP POLICY IF EXISTS "允许取消点赞" ON likes;
CREATE POLICY "允许查看点赞"     ON likes FOR SELECT USING (true);
CREATE POLICY "允许点赞"         ON likes FOR INSERT WITH CHECK (true);
CREATE POLICY "允许取消点赞"     ON likes FOR DELETE USING (true);

ALTER TABLE settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "允许读取设置" ON settings;
DROP POLICY IF EXISTS "允许修改设置" ON settings;
DROP POLICY IF EXISTS "允许插入设置" ON settings;
CREATE POLICY "允许读取设置"     ON settings FOR SELECT USING (true);
CREATE POLICY "允许修改设置"     ON settings FOR UPDATE USING (true);
CREATE POLICY "允许插入设置"     ON settings FOR INSERT WITH CHECK (true);

ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "允许读取任务" ON tasks;
DROP POLICY IF EXISTS "允许创建任务" ON tasks;
DROP POLICY IF EXISTS "允许修改任务" ON tasks;
DROP POLICY IF EXISTS "允许删除任务" ON tasks;
CREATE POLICY "允许读取任务"     ON tasks FOR SELECT USING (true);
CREATE POLICY "允许创建任务"     ON tasks FOR INSERT WITH CHECK (true);
CREATE POLICY "允许修改任务"     ON tasks FOR UPDATE USING (true);
CREATE POLICY "允许删除任务"     ON tasks FOR DELETE USING (true);

ALTER TABLE task_completions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "允许读取完成记录" ON task_completions;
DROP POLICY IF EXISTS "允许插入完成记录" ON task_completions;
CREATE POLICY "允许读取完成记录" ON task_completions FOR SELECT USING (true);
CREATE POLICY "允许插入完成记录" ON task_completions FOR INSERT WITH CHECK (true);

-- ==========================================
-- Storage：日记图片
-- ==========================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('diary-images', 'diary-images', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "允许上传日记图片" ON storage.objects;
DROP POLICY IF EXISTS "允许查看日记图片" ON storage.objects;

CREATE POLICY "允许上传日记图片"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'diary-images');

CREATE POLICY "允许查看日记图片"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'diary-images');

-- ==========================================
-- 预置默认管理员账号（管理员只管理老师与班级）
-- 用户名：admin    密码：147258369lss
-- 哈希算法：SHA-256('147258369lss' + 'pet-paradise-salt')
-- ==========================================
INSERT INTO profiles (username, password, role, points)
VALUES (
  'admin',
  'f981251676a58046eaa06c3066551aebbe4e7fb15638f21f45cff439463ef874',
  'teacher',
  0
)
ON CONFLICT (username) WHERE role = 'teacher' DO UPDATE SET role = 'teacher';

UPDATE profiles
SET is_admin = true
WHERE username = 'admin' AND role = 'teacher';

UPDATE profiles
SET is_admin = false
WHERE username = 'teacher' AND role = 'teacher';

-- Attach legacy students to the original teacher account.
UPDATE profiles AS student
SET teacher_id = teacher.id,
    class_name = COALESCE(student.class_name, teacher.class_name, '默认班级')
FROM profiles AS teacher
WHERE student.role = 'student'
  AND student.teacher_id IS NULL
  AND teacher.username = 'teacher'
  AND teacher.role = 'teacher';

UPDATE profiles
SET class_name = '默认班级'
WHERE role = 'teacher' AND class_name IS NULL;


-- Classroom transactions and weekly earnings
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
    SELECT t.*,CASE WHEN t.points > 0 THEN dense_rank() OVER (ORDER BY t.points DESC) ELSE NULL END AS rank,
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


-- Award revocation
-- 已部署课堂事务功能的项目执行；可重复执行。先迁移数据库，再发布前端。
BEGIN;
ALTER TABLE task_completions ADD COLUMN IF NOT EXISTS revoked_at TIMESTAMPTZ;
ALTER TABLE task_completions ADD COLUMN IF NOT EXISTS revoked_by UUID REFERENCES profiles(id);
ALTER TABLE task_completions ADD COLUMN IF NOT EXISTS revoke_reason TEXT;
-- 延续原项目的开放 RLS；撤销 RPC 使用调用者权限，需要允许写撤销元信息。
DROP POLICY IF EXISTS "允许撤销任务奖励" ON task_completions;
CREATE POLICY "允许撤销任务奖励" ON task_completions FOR UPDATE USING (true) WITH CHECK (true);
GRANT UPDATE (revoked_at, revoked_by, revoke_reason) ON task_completions TO anon, authenticated;

CREATE OR REPLACE FUNCTION revoke_task_award(p_actor_id UUID, p_completion_id UUID, p_reason TEXT)
RETURNS JSONB LANGUAGE plpgsql SECURITY INVOKER SET search_path = public AS $$
DECLARE c task_completions%ROWTYPE; s profiles%ROWTYPE; target_student UUID;
BEGIN
  SELECT student_id INTO target_student FROM task_completions WHERE id = p_completion_id;
  IF NOT FOUND THEN RAISE EXCEPTION '发放记录不存在'; END IF;
  -- 和喂食、发奖保持相同锁顺序，避免并发覆盖余额。
  SELECT * INTO s FROM profiles WHERE id = target_student AND role = 'student' FOR UPDATE;
  IF NOT FOUND OR p_actor_id IS NULL OR s.teacher_id IS DISTINCT FROM p_actor_id
    OR NOT EXISTS(SELECT 1 FROM profiles WHERE id = p_actor_id AND role = 'teacher') THEN
    RAISE EXCEPTION '只能撤销本班学生的奖励';
  END IF;
  SELECT * INTO c FROM task_completions WHERE id = p_completion_id FOR UPDATE;
  IF NOT FOUND OR c.student_id IS DISTINCT FROM s.id OR c.awarded_by IS DISTINCT FROM p_actor_id THEN
    RAISE EXCEPTION '只能撤销自己发放的奖励';
  END IF;
  -- 以原发奖记录为幂等键，丢失响应后的重试也不重复扣分。
  IF c.revoked_at IS NOT NULL THEN
    RETURN jsonb_build_object('balance',s.points,'completion',to_jsonb(c),'alreadyRevoked',true);
  END IF;
  IF length(trim(COALESCE(p_reason,''))) NOT BETWEEN 1 AND 200 THEN
    RAISE EXCEPTION '请填写 1 至 200 字的撤销原因';
  END IF;
  IF c.points <= 0 THEN RAISE EXCEPTION '该记录不是正积分奖励，无法撤销'; END IF;
  IF COALESCE(s.points,0) < c.points THEN
    RAISE EXCEPTION '学生当前余额为 % 分，不足以收回 % 分，暂时无法撤销', COALESCE(s.points,0),c.points;
  END IF;
  UPDATE profiles SET points = points - c.points WHERE id = s.id RETURNING * INTO s;
  IF NOT FOUND THEN RAISE EXCEPTION '余额更新失败，未撤销奖励'; END IF;
  UPDATE task_completions SET revoked_at = now(), revoked_by = p_actor_id, revoke_reason = trim(p_reason)
    WHERE id = c.id RETURNING * INTO c;
  IF NOT FOUND THEN RAISE EXCEPTION '撤销记录写入失败，积分未扣除'; END IF;
  RETURN jsonb_build_object('balance',s.points,'completion',to_jsonb(c),'alreadyRevoked',false);
END $$;

CREATE OR REPLACE FUNCTION teacher_award_total(p_teacher_id UUID)
RETURNS BIGINT LANGUAGE sql STABLE SECURITY INVOKER SET search_path = public AS $$
  SELECT COALESCE(sum(points),0) FROM task_completions WHERE awarded_by = p_teacher_id AND revoked_at IS NULL;
$$;

CREATE OR REPLACE FUNCTION weekly_leaderboard(p_teacher_id UUID)
RETURNS JSONB LANGUAGE sql STABLE SECURITY INVOKER SET search_path = public AS $$
  WITH period AS (
    SELECT date_trunc('week',now() AT TIME ZONE 'Asia/Shanghai') AT TIME ZONE 'Asia/Shanghai' AS start_at
  ), totals AS (
    SELECT p.id,p.username,COALESCE(sum(e.points),0) AS points
    FROM profiles p CROSS JOIN period w
    LEFT JOIN point_earnings e ON e.student_id = p.id AND e.teacher_id = p_teacher_id
      AND e.created_at >= w.start_at AND e.created_at < w.start_at + interval '7 days'
      AND NOT EXISTS (SELECT 1 FROM task_completions c WHERE 'task:' || c.id = e.source_id AND c.revoked_at IS NOT NULL)
    WHERE p.teacher_id = p_teacher_id AND p.role = 'student'
    GROUP BY p.id,p.username
  ), ranked AS (
    SELECT t.*,CASE WHEN t.points > 0 THEN dense_rank() OVER (ORDER BY t.points DESC) ELSE NULL END AS rank,
      COALESCE(pet.level,0) AS pet_level,COALESCE(pet.name,'未领养') AS pet_name
    FROM totals t LEFT JOIN LATERAL (
      SELECT name,level FROM pets WHERE owner_id = t.id ORDER BY level DESC,created_at,id LIMIT 1
    ) pet ON true
  ) SELECT jsonb_build_object('weekStart',w.start_at,'weekEnd',w.start_at + interval '7 days',
    'entries',COALESCE((SELECT jsonb_agg(to_jsonb(r) ORDER BY r.points DESC,r.username,r.id) FROM ranked r),'[]'::JSONB))
  FROM period w;
$$;
GRANT EXECUTE ON FUNCTION revoke_task_award(UUID,UUID,TEXT), teacher_award_total(UUID) TO anon, authenticated;
COMMIT;
