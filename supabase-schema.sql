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

-- 删除老师时保留其历史任务与奖励记录，仅清空创建人/发放人引用。
-- DROP/ADD 同时修复已经按旧版 schema 创建的数据库。
ALTER TABLE tasks DROP CONSTRAINT IF EXISTS tasks_created_by_fkey;
ALTER TABLE tasks
  ADD CONSTRAINT tasks_created_by_fkey
  FOREIGN KEY (created_by) REFERENCES profiles(id) ON DELETE SET NULL;
ALTER TABLE task_completions DROP CONSTRAINT IF EXISTS task_completions_awarded_by_fkey;
ALTER TABLE task_completions
  ADD CONSTRAINT task_completions_awarded_by_fkey
  FOREIGN KEY (awarded_by) REFERENCES profiles(id) ON DELETE SET NULL;

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


-- Award revocation
-- 已部署课堂事务功能的项目执行；可重复执行。先迁移数据库，再发布前端。
BEGIN;
ALTER TABLE task_completions ADD COLUMN IF NOT EXISTS revoked_at TIMESTAMPTZ;
ALTER TABLE task_completions ADD COLUMN IF NOT EXISTS revoked_by UUID REFERENCES profiles(id);
ALTER TABLE task_completions DROP CONSTRAINT IF EXISTS task_completions_revoked_by_fkey;
ALTER TABLE task_completions
  ADD CONSTRAINT task_completions_revoked_by_fkey
  FOREIGN KEY (revoked_by) REFERENCES profiles(id) ON DELETE SET NULL;
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
    SELECT t.*,CASE WHEN t.points > 0 THEN row_number() OVER (ORDER BY t.points DESC,t.username,t.id) ELSE NULL END AS rank,
      COALESCE(pet.level,0) AS pet_level,COALESCE(pet.name,'未领养') AS pet_name
    FROM totals t LEFT JOIN LATERAL (
      SELECT name,level FROM pets WHERE owner_id = t.id ORDER BY level DESC,created_at,id LIMIT 1
    ) pet ON true
  ) SELECT jsonb_build_object('weekStart',w.start_at,'weekEnd',w.start_at + interval '7 days',
    'entries',COALESCE((SELECT jsonb_agg(to_jsonb(r) ORDER BY r.points DESC,r.username,r.id) FROM ranked r),'[]'::JSONB))
  FROM period w;
$$;
GRANT EXECUTE ON FUNCTION revoke_task_award(UUID,UUID,TEXT), teacher_award_total(UUID) TO anon, authenticated;

CREATE OR REPLACE FUNCTION change_student_password(
  p_actor_id UUID, p_current_password TEXT, p_new_password TEXT
) RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF p_actor_id IS NULL OR COALESCE(p_current_password,'')='' OR COALESCE(p_new_password,'')='' THEN RAISE EXCEPTION '密码参数不完整'; END IF;
  IF NOT EXISTS(SELECT 1 FROM profiles WHERE id=p_actor_id AND role='student' AND password=p_current_password) THEN RAISE EXCEPTION '当前密码不正确'; END IF;
  UPDATE profiles SET password=p_new_password WHERE id=p_actor_id AND role='student';
  RETURN true;
END $$;

CREATE OR REPLACE FUNCTION teacher_reset_student_password(
  p_actor_id UUID, p_student_id UUID, p_new_password TEXT
) RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF p_actor_id IS NULL OR p_student_id IS NULL OR COALESCE(p_new_password,'')='' THEN RAISE EXCEPTION '密码参数不完整'; END IF;
  IF NOT EXISTS(SELECT 1 FROM profiles WHERE id=p_actor_id AND role='teacher')
    OR NOT EXISTS(SELECT 1 FROM profiles WHERE id=p_student_id AND role='student' AND teacher_id=p_actor_id) THEN RAISE EXCEPTION '只能重置自己班级学生的密码'; END IF;
  UPDATE profiles SET password=p_new_password WHERE id=p_student_id;
  RETURN true;
END $$;
GRANT EXECUTE ON FUNCTION change_student_password(UUID,TEXT,TEXT),teacher_reset_student_password(UUID,UUID,TEXT) TO anon,authenticated;
COMMIT;

-- 商城：卡片边框、背景、拥有关系、装备状态与购买记录。
-- 可重复执行。部署前端前先在 Supabase SQL Editor 执行本文件。
BEGIN;

CREATE TABLE IF NOT EXISTS shop_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  category TEXT NOT NULL CHECK (category IN ('frame', 'background')),
  style_key TEXT NOT NULL,
  price INTEGER NOT NULL CHECK (price >= 0),
  icon TEXT NOT NULL DEFAULT '✨',
  sort_order INTEGER NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(category, style_key)
);

CREATE TABLE IF NOT EXISTS shop_orders (
  id UUID PRIMARY KEY,
  buyer_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  actor_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  item_id UUID NOT NULL REFERENCES shop_items(id),
  price INTEGER NOT NULL CHECK (price >= 0),
  balance_after INTEGER NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(buyer_id, item_id)
);

ALTER TABLE shop_orders ADD COLUMN IF NOT EXISTS actor_id UUID REFERENCES profiles(id) ON DELETE SET NULL;
UPDATE shop_orders SET actor_id=buyer_id WHERE actor_id IS NULL;

CREATE TABLE IF NOT EXISTS user_items (
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  item_id UUID NOT NULL REFERENCES shop_items(id),
  order_id UUID NOT NULL REFERENCES shop_orders(id),
  acquired_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY(user_id, item_id)
);

CREATE TABLE IF NOT EXISTS pet_cosmetics (
  pet_id UUID PRIMARY KEY REFERENCES pets(id) ON DELETE CASCADE,
  frame_item_id UUID REFERENCES shop_items(id) ON DELETE SET NULL,
  background_item_id UUID REFERENCES shop_items(id) ON DELETE SET NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS shop_orders_buyer_created_idx ON shop_orders(buyer_id, created_at DESC);
CREATE INDEX IF NOT EXISTS user_items_user_idx ON user_items(user_id);

ALTER TABLE shop_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE shop_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE pet_cosmetics ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "允许查看商品" ON shop_items;
CREATE POLICY "允许查看商品" ON shop_items FOR SELECT USING (true);
DROP POLICY IF EXISTS "允许查看购买记录" ON shop_orders;
CREATE POLICY "允许查看购买记录" ON shop_orders FOR SELECT USING (true);
DROP POLICY IF EXISTS "允许查看已有装扮" ON user_items;
CREATE POLICY "允许查看已有装扮" ON user_items FOR SELECT USING (true);
DROP POLICY IF EXISTS "允许查看当前装扮" ON pet_cosmetics;
CREATE POLICY "允许查看当前装扮" ON pet_cosmetics FOR SELECT USING (true);

INSERT INTO shop_items(slug,name,description,category,style_key,price,icon,sort_order) VALUES
  ('frame-leaf','森语藤蔓','清新的叶片环绕卡片','frame','leaf',35,'🌿',10),
  ('frame-candy','糖果泡泡','柔软明亮的糖果色边框','frame','candy',55,'🍬',20),
  ('frame-starlight','星光流转','闪耀的蓝紫星光边框','frame','starlight',90,'🌟',30),
  ('frame-gold','荣耀金冠','为坚持成长的宠物加冕','frame','gold',160,'👑',40),
  ('background-meadow','晨光草地','像在清晨的草地上散步','background','meadow',30,'🌱',110),
  ('background-sunset','蜜桃晚霞','温暖柔和的粉橙晚霞','background','sunset',50,'🌅',120),
  ('background-ocean','海盐气泡','清凉的海蓝色波光','background','ocean',75,'🌊',130),
  ('background-night','银河夜游','深蓝星河中的安静旅程','background','night',120,'🌌',140),
  ('background-hidden','隐藏背景','去掉主题背景，保持简洁透明','background','hidden',20,'🪟',150)
ON CONFLICT (slug) DO UPDATE SET
  name=EXCLUDED.name,description=EXCLUDED.description,category=EXCLUDED.category,
  style_key=EXCLUDED.style_key,price=EXCLUDED.price,icon=EXCLUDED.icon,sort_order=EXCLUDED.sort_order;

CREATE OR REPLACE FUNCTION purchase_shop_item(
  p_buyer_id UUID, p_item_id UUID, p_request_id UUID
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE buyer profiles%ROWTYPE; item shop_items%ROWTYPE; existing shop_orders%ROWTYPE;
BEGIN
  IF p_buyer_id IS NULL OR p_item_id IS NULL OR p_request_id IS NULL THEN RAISE EXCEPTION '无效的购买请求'; END IF;
  SELECT * INTO buyer FROM profiles WHERE id=p_buyer_id AND role='student' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION '学生不存在'; END IF;
  SELECT * INTO existing FROM shop_orders WHERE id=p_request_id;
  IF FOUND THEN
    IF existing.buyer_id IS DISTINCT FROM p_buyer_id OR existing.item_id IS DISTINCT FROM p_item_id THEN RAISE EXCEPTION '请求编号已用于其他购买'; END IF;
    RETURN jsonb_build_object('balance',existing.balance_after,'order',to_jsonb(existing),'alreadyOwned',false);
  END IF;
  IF EXISTS(SELECT 1 FROM user_items WHERE user_id=p_buyer_id AND item_id=p_item_id) THEN
    RETURN jsonb_build_object('balance',buyer.points,'alreadyOwned',true);
  END IF;
  -- 商品目录只有公开读取策略；FOR SHARE 会额外触发行级锁权限并被 RLS 过滤。
  -- 价格以购买事务读取到的当前值为准，无需锁定商品目录行。
  SELECT * INTO item FROM shop_items WHERE id=p_item_id AND is_active=true;
  IF NOT FOUND THEN RAISE EXCEPTION '商品已下架'; END IF;
  IF COALESCE(buyer.points,0) < item.price THEN RAISE EXCEPTION '积分不足，需要 % 积分',item.price; END IF;
  UPDATE profiles SET points=COALESCE(points,0)-item.price WHERE id=p_buyer_id RETURNING * INTO buyer;
  INSERT INTO shop_orders(id,buyer_id,actor_id,item_id,price,balance_after)
    VALUES(p_request_id,p_buyer_id,p_buyer_id,item.id,item.price,buyer.points) RETURNING * INTO existing;
  INSERT INTO user_items(user_id,item_id,order_id) VALUES(p_buyer_id,item.id,existing.id);
  RETURN jsonb_build_object('balance',buyer.points,'order',to_jsonb(existing),'alreadyOwned',false);
END $$;

CREATE OR REPLACE FUNCTION teacher_purchase_shop_item(
  p_actor_id UUID, p_student_id UUID, p_item_id UUID, p_request_id UUID
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE student profiles%ROWTYPE; item shop_items%ROWTYPE; existing shop_orders%ROWTYPE;
BEGIN
  IF p_actor_id IS NULL OR p_student_id IS NULL OR p_item_id IS NULL OR p_request_id IS NULL THEN RAISE EXCEPTION '无效的代购请求'; END IF;
  SELECT * INTO student FROM profiles WHERE id=p_student_id AND role='student' FOR UPDATE;
  IF NOT FOUND OR student.teacher_id IS DISTINCT FROM p_actor_id
    OR NOT EXISTS(SELECT 1 FROM profiles WHERE id=p_actor_id AND role='teacher') THEN RAISE EXCEPTION '只能操作自己班级的学生'; END IF;
  SELECT * INTO existing FROM shop_orders WHERE id=p_request_id;
  IF FOUND THEN
    IF existing.buyer_id IS DISTINCT FROM p_student_id OR existing.item_id IS DISTINCT FROM p_item_id OR existing.actor_id IS DISTINCT FROM p_actor_id THEN RAISE EXCEPTION '请求编号已用于其他购买'; END IF;
    RETURN jsonb_build_object('balance',existing.balance_after,'order',to_jsonb(existing),'alreadyOwned',false);
  END IF;
  IF EXISTS(SELECT 1 FROM user_items WHERE user_id=p_student_id AND item_id=p_item_id) THEN
    RETURN jsonb_build_object('balance',student.points,'alreadyOwned',true);
  END IF;
  SELECT * INTO item FROM shop_items WHERE id=p_item_id AND is_active=true;
  IF NOT FOUND THEN RAISE EXCEPTION '商品已下架'; END IF;
  IF COALESCE(student.points,0) < item.price THEN RAISE EXCEPTION '学生积分不足，需要 % 积分',item.price; END IF;
  UPDATE profiles SET points=COALESCE(points,0)-item.price WHERE id=p_student_id RETURNING * INTO student;
  INSERT INTO shop_orders(id,buyer_id,actor_id,item_id,price,balance_after)
    VALUES(p_request_id,p_student_id,p_actor_id,item.id,item.price,student.points) RETURNING * INTO existing;
  INSERT INTO user_items(user_id,item_id,order_id) VALUES(p_student_id,item.id,existing.id);
  RETURN jsonb_build_object('balance',student.points,'order',to_jsonb(existing),'alreadyOwned',false);
END $$;

CREATE OR REPLACE FUNCTION teacher_equip_pet_cosmetic(
  p_actor_id UUID, p_student_id UUID, p_pet_id UUID, p_category TEXT, p_item_id UUID DEFAULT NULL
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE item shop_items%ROWTYPE; equipped pet_cosmetics%ROWTYPE;
BEGIN
  IF p_category NOT IN ('frame','background') THEN RAISE EXCEPTION '无效的装扮类型'; END IF;
  IF NOT EXISTS(SELECT 1 FROM profiles WHERE id=p_actor_id AND role='teacher')
    OR NOT EXISTS(SELECT 1 FROM profiles WHERE id=p_student_id AND role='student' AND teacher_id=p_actor_id)
    OR NOT EXISTS(SELECT 1 FROM pets WHERE id=p_pet_id AND owner_id=p_student_id) THEN RAISE EXCEPTION '只能装扮自己班级学生的宠物'; END IF;
  IF p_item_id IS NOT NULL THEN
    SELECT i.* INTO item FROM shop_items i JOIN user_items u ON u.item_id=i.id
      WHERE i.id=p_item_id AND u.user_id=p_student_id AND i.category=p_category AND i.is_active=true;
    IF NOT FOUND THEN RAISE EXCEPTION '学生尚未拥有该装扮'; END IF;
  END IF;
  INSERT INTO pet_cosmetics(pet_id,frame_item_id,background_item_id)
    VALUES(p_pet_id,CASE WHEN p_category='frame' THEN p_item_id END,CASE WHEN p_category='background' THEN p_item_id END)
  ON CONFLICT (pet_id) DO UPDATE SET
    frame_item_id=CASE WHEN p_category='frame' THEN p_item_id ELSE pet_cosmetics.frame_item_id END,
    background_item_id=CASE WHEN p_category='background' THEN p_item_id ELSE pet_cosmetics.background_item_id END,
    updated_at=now()
  RETURNING * INTO equipped;
  RETURN to_jsonb(equipped);
END $$;

CREATE OR REPLACE FUNCTION equip_pet_cosmetic(
  p_actor_id UUID, p_pet_id UUID, p_category TEXT, p_item_id UUID DEFAULT NULL
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE item shop_items%ROWTYPE; equipped pet_cosmetics%ROWTYPE;
BEGIN
  IF p_category NOT IN ('frame','background') THEN RAISE EXCEPTION '无效的装扮类型'; END IF;
  IF NOT EXISTS(SELECT 1 FROM pets WHERE id=p_pet_id AND owner_id=p_actor_id)
    OR NOT EXISTS(SELECT 1 FROM profiles WHERE id=p_actor_id AND role='student') THEN RAISE EXCEPTION '只能装扮自己的宠物'; END IF;
  IF p_item_id IS NOT NULL THEN
    SELECT i.* INTO item FROM shop_items i JOIN user_items u ON u.item_id=i.id
      WHERE i.id=p_item_id AND u.user_id=p_actor_id AND i.category=p_category;
    IF NOT FOUND THEN RAISE EXCEPTION '尚未拥有该装扮'; END IF;
  END IF;
  INSERT INTO pet_cosmetics(pet_id,frame_item_id,background_item_id)
    VALUES(p_pet_id,CASE WHEN p_category='frame' THEN p_item_id END,CASE WHEN p_category='background' THEN p_item_id END)
  ON CONFLICT (pet_id) DO UPDATE SET
    frame_item_id=CASE WHEN p_category='frame' THEN p_item_id ELSE pet_cosmetics.frame_item_id END,
    background_item_id=CASE WHEN p_category='background' THEN p_item_id ELSE pet_cosmetics.background_item_id END,
    updated_at=now()
  RETURNING * INTO equipped;
  RETURN to_jsonb(equipped);
END $$;

GRANT SELECT ON shop_items,shop_orders,user_items,pet_cosmetics TO anon,authenticated;
REVOKE INSERT, UPDATE, DELETE ON shop_orders,user_items,pet_cosmetics FROM anon,authenticated;
GRANT EXECUTE ON FUNCTION purchase_shop_item(UUID,UUID,UUID),equip_pet_cosmetic(UUID,UUID,TEXT,UUID),teacher_purchase_shop_item(UUID,UUID,UUID,UUID),teacher_equip_pet_cosmetic(UUID,UUID,UUID,TEXT,UUID) TO anon,authenticated;
COMMIT;

-- 宠物旅行。先执行商城迁移，再执行本文件；可重复执行。
-- 沿用项目现有自定义账号 RPC 身份模型（调用方传学生 ID）。
BEGIN;
ALTER TABLE shop_items ADD COLUMN IF NOT EXISTS acquisition TEXT NOT NULL DEFAULT 'shop'
  CHECK (acquisition IN ('shop','travel'));
ALTER TABLE user_items ALTER COLUMN order_id DROP NOT NULL;

CREATE TABLE IF NOT EXISTS travel_destinations (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  icon TEXT NOT NULL,
  description TEXT NOT NULL,
  hours INTEGER NOT NULL CHECK (hours > 0),
  stories TEXT[] NOT NULL CHECK (cardinality(stories) > 0),
  sort_order INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS travel_rewards (
  item_id UUID PRIMARY KEY REFERENCES shop_items(id),
  destination_id TEXT NOT NULL REFERENCES travel_destinations(id),
  stamp_cost INTEGER NOT NULL DEFAULT 8 CHECK (stamp_cost > 0)
);
CREATE TABLE IF NOT EXISTS travel_wallets (
  user_id UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
  stamps INTEGER NOT NULL DEFAULT 0 CHECK (stamps >= 0)
);
CREATE TABLE IF NOT EXISTS pet_trips (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  pet_id UUID REFERENCES pets(id) ON DELETE SET NULL,
  pet_name TEXT NOT NULL,
  destination_id TEXT NOT NULL REFERENCES travel_destinations(id),
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  departure_day DATE NOT NULL DEFAULT (now() AT TIME ZONE 'Asia/Shanghai')::date,
  returns_at TIMESTAMPTZ NOT NULL,
  claimed_at TIMESTAMPTZ,
  reward JSONB,
  UNIQUE(user_id, departure_day),
  CHECK (returns_at > started_at),
  CHECK ((claimed_at IS NULL) = (reward IS NULL))
);
CREATE UNIQUE INDEX IF NOT EXISTS pet_trips_one_active ON pet_trips(user_id) WHERE claimed_at IS NULL;

INSERT INTO travel_destinations VALUES
 ('forest','森林营地','🌲','沿着林间小径，寻找藏在树叶里的惊喜。',4,ARRAY['今天遇见了一只松鼠，它送给我一片心形的叶子。','在溪水边歇了歇脚，把森林清晨的声音带回来给你。','搭好小帐篷后，看见萤火虫在树间点起了灯。'],1),
 ('coast','贝壳海湾','🐚','听海浪说话，把海边的温柔装进行李。',8,ARRAY['今天在海边捡到一枚漂亮的贝壳，想带回来送给你。','小螃蟹教我在沙滩上画画，我画的是你！','等到了橘子色的日落，把这一刻寄给最想念的你。'],2),
 ('stars','星光山谷','🌌','走向静谧山谷，收藏一整晚的星光。',12,ARRAY['抬头数星星的时候，每一颗都像你给我的鼓励。','在山顶看见一颗流星，偷偷许了和你有关的愿望。','裹着小毯子等天亮，把第一缕晨光装进了背包。'],3)
ON CONFLICT (id) DO UPDATE SET name=EXCLUDED.name,icon=EXCLUDED.icon,description=EXCLUDED.description,hours=EXCLUDED.hours,stories=EXCLUDED.stories;

INSERT INTO shop_items(slug,name,description,category,style_key,price,icon,sort_order,acquisition) VALUES
 ('travel-forest-frame','林间邮票','森林营地专属边框','frame','travel-forest',0,'🌿',210,'travel'),
 ('travel-forest-bg','萤火森林','森林营地专属背景','background','travel-forest',0,'🌲',211,'travel'),
 ('travel-coast-frame','贝壳来信','贝壳海湾专属边框','frame','travel-coast',0,'🐚',220,'travel'),
 ('travel-coast-bg','晴日海岸','贝壳海湾专属背景','background','travel-coast',0,'🏖️',221,'travel'),
 ('travel-stars-frame','星轨信笺','星光山谷专属边框','frame','travel-stars',0,'✨',230,'travel'),
 ('travel-stars-bg','山谷星河','星光山谷专属背景','background','travel-stars',0,'🌌',231,'travel')
ON CONFLICT (slug) DO UPDATE SET name=EXCLUDED.name,description=EXCLUDED.description,acquisition=EXCLUDED.acquisition;
INSERT INTO travel_rewards(item_id,destination_id)
 SELECT id,split_part(slug,'-',2) FROM shop_items WHERE slug IN
 ('travel-forest-frame','travel-forest-bg','travel-coast-frame','travel-coast-bg','travel-stars-frame','travel-stars-bg')
ON CONFLICT (item_id) DO NOTHING;

-- 同时覆盖学生购买和老师代购；事务失败会回滚积分扣除。
CREATE OR REPLACE FUNCTION reject_travel_purchase() RETURNS TRIGGER
LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
 IF EXISTS(SELECT 1 FROM shop_items WHERE id=NEW.item_id AND acquisition='travel') THEN
   RAISE EXCEPTION '旅行专属装扮，请通过旅行或印章兑换获得';
 END IF;
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS reject_travel_purchase ON shop_orders;
CREATE TRIGGER reject_travel_purchase BEFORE INSERT OR UPDATE ON shop_orders
 FOR EACH ROW EXECUTE FUNCTION reject_travel_purchase();

CREATE OR REPLACE FUNCTION travel_state(p_user_id UUID) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM profiles WHERE id=p_user_id AND role='student') THEN RAISE EXCEPTION '学生不存在'; END IF;
 RETURN jsonb_build_object(
  'serverNow',now(),
  'nextReset',(((now() AT TIME ZONE 'Asia/Shanghai')::date+1)::timestamp AT TIME ZONE 'Asia/Shanghai'),
  'canDepart',NOT EXISTS(SELECT 1 FROM pet_trips WHERE user_id=p_user_id AND (claimed_at IS NULL OR departure_day=(now() AT TIME ZONE 'Asia/Shanghai')::date)),
  'stamps',COALESCE((SELECT stamps FROM travel_wallets WHERE user_id=p_user_id),0),
  'destinations',(SELECT jsonb_agg(to_jsonb(d) ORDER BY sort_order) FROM travel_destinations d),
  'items',COALESCE((SELECT jsonb_agg(to_jsonb(i)||jsonb_build_object('destination_id',r.destination_id,'stamp_cost',r.stamp_cost,'owned',EXISTS(SELECT 1 FROM user_items u WHERE u.user_id=p_user_id AND u.item_id=i.id)) ORDER BY i.sort_order) FROM travel_rewards r JOIN shop_items i ON i.id=r.item_id),'[]'::jsonb),
  'active',(SELECT to_jsonb(t) FROM pet_trips t WHERE user_id=p_user_id AND claimed_at IS NULL),
  'history',COALESCE((SELECT jsonb_agg(to_jsonb(h) ORDER BY started_at DESC) FROM (SELECT * FROM pet_trips WHERE user_id=p_user_id AND claimed_at IS NOT NULL ORDER BY started_at DESC LIMIT 20) h),'[]'::jsonb),
  'postcards',COALESCE((SELECT jsonb_agg(c) FROM (SELECT DISTINCT destination_id,reward->>'story' AS story FROM pet_trips WHERE user_id=p_user_id AND claimed_at IS NOT NULL) c),'[]'::jsonb)
 );
END $$;

CREATE OR REPLACE FUNCTION start_pet_trip(p_user_id UUID,p_pet_id UUID,p_destination_id TEXT,p_request_id UUID) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE d travel_destinations%ROWTYPE; t pet_trips%ROWTYPE; pet_name_value TEXT;
BEGIN
 PERFORM 1 FROM profiles WHERE id=p_user_id AND role='student' FOR UPDATE;
 IF NOT FOUND OR p_request_id IS NULL THEN RAISE EXCEPTION '无效的出发请求'; END IF;
 SELECT * INTO t FROM pet_trips WHERE id=p_request_id;
 IF FOUND THEN
  IF t.user_id IS DISTINCT FROM p_user_id OR t.pet_id IS DISTINCT FROM p_pet_id OR t.destination_id IS DISTINCT FROM p_destination_id THEN RAISE EXCEPTION '请求编号已被使用'; END IF;
  RETURN to_jsonb(t);
 END IF;
 SELECT name INTO pet_name_value FROM pets WHERE id=p_pet_id AND owner_id=p_user_id FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION '请选择自己的宠物'; END IF;
 IF EXISTS(SELECT 1 FROM pet_trips WHERE user_id=p_user_id AND claimed_at IS NULL) THEN RAISE EXCEPTION '请先等待宠物归来并领取行李'; END IF;
 IF EXISTS(SELECT 1 FROM pet_trips WHERE user_id=p_user_id AND departure_day=(now() AT TIME ZONE 'Asia/Shanghai')::date) THEN RAISE EXCEPTION '今天已经出发过啦，明天再来吧'; END IF;
 SELECT * INTO d FROM travel_destinations WHERE id=p_destination_id;
 IF NOT FOUND THEN RAISE EXCEPTION '目的地不存在'; END IF;
 INSERT INTO pet_trips(id,user_id,pet_id,pet_name,destination_id,returns_at)
 VALUES(p_request_id,p_user_id,p_pet_id,pet_name_value,d.id,now()+make_interval(hours=>d.hours)) RETURNING * INTO t;
 RETURN to_jsonb(t);
END $$;

CREATE OR REPLACE FUNCTION claim_pet_trip(p_user_id UUID,p_trip_id UUID) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE t pet_trips%ROWTYPE; d travel_destinations%ROWTYPE; item shop_items%ROWTYPE;
 story TEXT; bonus INTEGER := 1; duplicate BOOLEAN := false; result JSONB;
BEGIN
 PERFORM 1 FROM profiles WHERE id=p_user_id AND role='student' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION '学生不存在'; END IF;
 SELECT * INTO t FROM pet_trips WHERE id=p_trip_id AND user_id=p_user_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION '旅行记录不存在'; END IF;
 IF t.claimed_at IS NOT NULL THEN RETURN t.reward; END IF;
 IF now()<t.returns_at THEN RAISE EXCEPTION '宠物还在路上，请耐心等待'; END IF;
 SELECT * INTO d FROM travel_destinations WHERE id=t.destination_id;
 story := d.stories[1+floor(random()*cardinality(d.stories))::integer];
 -- 每次保底明信片及 1 印章；1% 概率获得当地装扮，两款均分。
 IF random()<0.01 THEN
  SELECT i.* INTO item FROM travel_rewards r JOIN shop_items i ON i.id=r.item_id WHERE r.destination_id=d.id ORDER BY random() LIMIT 1;
  IF FOUND THEN
   duplicate := EXISTS(SELECT 1 FROM user_items WHERE user_id=p_user_id AND item_id=item.id);
   IF duplicate THEN bonus := bonus+2;
   ELSE INSERT INTO user_items(user_id,item_id) VALUES(p_user_id,item.id); END IF;
  END IF;
 END IF;
 INSERT INTO travel_wallets(user_id,stamps) VALUES(p_user_id,bonus)
 ON CONFLICT (user_id) DO UPDATE SET stamps=travel_wallets.stamps+EXCLUDED.stamps;
 result := jsonb_build_object('story',story,'stamps',bonus,'duplicate',duplicate,'item',CASE WHEN item.id IS NOT NULL THEN to_jsonb(item) ELSE NULL END);
 UPDATE pet_trips SET claimed_at=now(),reward=result WHERE id=t.id;
 RETURN result;
END $$;

CREATE OR REPLACE FUNCTION redeem_travel_item(p_user_id UUID,p_item_id UUID) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE cost INTEGER;
BEGIN
 PERFORM 1 FROM profiles WHERE id=p_user_id AND role='student' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION '学生不存在'; END IF;
 SELECT stamp_cost INTO cost FROM travel_rewards WHERE item_id=p_item_id;
 IF NOT FOUND THEN RAISE EXCEPTION '无法兑换该装扮'; END IF;
 IF EXISTS(SELECT 1 FROM user_items WHERE user_id=p_user_id AND item_id=p_item_id) THEN RETURN jsonb_build_object('alreadyOwned',true); END IF;
 UPDATE travel_wallets SET stamps=stamps-cost WHERE user_id=p_user_id AND stamps>=cost;
 IF NOT FOUND THEN RAISE EXCEPTION '旅行印章不足'; END IF;
 INSERT INTO user_items(user_id,item_id) VALUES(p_user_id,p_item_id);
 RETURN jsonb_build_object('alreadyOwned',false);
END $$;

ALTER TABLE travel_destinations ENABLE ROW LEVEL SECURITY;
ALTER TABLE travel_rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE travel_wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE pet_trips ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON travel_destinations,travel_rewards,travel_wallets,pet_trips FROM anon,authenticated;
REVOKE ALL ON FUNCTION travel_state(UUID),start_pet_trip(UUID,UUID,TEXT,UUID),claim_pet_trip(UUID,UUID),redeem_travel_item(UUID,UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION travel_state(UUID),start_pet_trip(UUID,UUID,TEXT,UUID),claim_pet_trip(UUID,UUID),redeem_travel_item(UUID,UUID) TO anon,authenticated;
COMMIT;

-- 任务奖励旅行券。先执行课堂、商城、旅行迁移，再执行本文件；可重复执行。
BEGIN;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS travel_tickets INTEGER NOT NULL DEFAULT 0 CHECK (travel_tickets BETWEEN 0 AND 100);
ALTER TABLE task_completions ADD COLUMN IF NOT EXISTS travel_tickets INTEGER NOT NULL DEFAULT 0 CHECK (travel_tickets >= 0);
ALTER TABLE task_completions ADD COLUMN IF NOT EXISTS revoked_at TIMESTAMPTZ;
ALTER TABLE task_completions ADD COLUMN IF NOT EXISTS revoked_by UUID REFERENCES profiles(id);
ALTER TABLE task_completions ADD COLUMN IF NOT EXISTS revoke_reason TEXT;
ALTER TABLE travel_wallets ADD COLUMN IF NOT EXISTS tickets INTEGER NOT NULL DEFAULT 0 CHECK (tickets >= 0);
-- 已出发的历史免费旅行继续有效，不补扣券。
ALTER TABLE pet_trips ADD COLUMN IF NOT EXISTS ticket_cost INTEGER NOT NULL DEFAULT 0 CHECK (ticket_cost IN (0,1));
ALTER TABLE pet_trips DROP CONSTRAINT IF EXISTS pet_trips_user_id_departure_day_key;

CREATE OR REPLACE FUNCTION award_task_points(
 p_actor_id UUID,p_student_id UUID,p_task_id UUID,p_request_id UUID
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE s profiles%ROWTYPE; t tasks%ROWTYPE; c task_completions%ROWTYPE;
BEGIN
 IF p_request_id IS NULL THEN RAISE EXCEPTION '缺少请求编号'; END IF;
 SELECT * INTO s FROM profiles WHERE id=p_student_id AND role='student' FOR UPDATE;
 IF NOT FOUND OR p_actor_id IS NULL OR s.teacher_id IS DISTINCT FROM p_actor_id
   OR NOT EXISTS(SELECT 1 FROM profiles WHERE id=p_actor_id AND role='teacher') THEN RAISE EXCEPTION '只能给本班学生发放奖励'; END IF;
 SELECT * INTO c FROM task_completions WHERE id=p_request_id;
 IF FOUND THEN
  IF c.student_id IS DISTINCT FROM s.id OR c.awarded_by IS DISTINCT FROM p_actor_id OR c.task_id IS DISTINCT FROM p_task_id THEN RAISE EXCEPTION '请求编号已用于其他操作'; END IF;
  RETURN jsonb_build_object('points',c.points,'travelTickets',c.travel_tickets,'balance',s.points);
 END IF;
 SELECT * INTO t FROM tasks WHERE id=p_task_id AND created_by=p_actor_id AND is_active=true FOR SHARE;
 IF NOT FOUND OR t.points IS NULL OR t.points<0 OR (t.points=0 AND t.travel_tickets=0) THEN RAISE EXCEPTION '任务已停用或未设置有效奖励'; END IF;
 INSERT INTO task_completions(id,task_id,student_id,awarded_by,points,travel_tickets)
 VALUES(p_request_id,t.id,s.id,p_actor_id,t.points,t.travel_tickets);
 UPDATE profiles SET points=COALESCE(points,0)+t.points WHERE id=s.id RETURNING * INTO s;
 IF t.points>0 THEN
  INSERT INTO point_earnings(source_id,student_id,teacher_id,points,reason) VALUES('task:'||p_request_id,s.id,p_actor_id,t.points,t.name);
 END IF;
 IF t.travel_tickets>0 THEN
  INSERT INTO travel_wallets(user_id,tickets) VALUES(s.id,t.travel_tickets)
  ON CONFLICT (user_id) DO UPDATE SET tickets=travel_wallets.tickets+EXCLUDED.tickets;
 END IF;
 RETURN jsonb_build_object('points',t.points,'travelTickets',t.travel_tickets,'balance',s.points);
END $$;

CREATE OR REPLACE FUNCTION revoke_task_award(p_actor_id UUID,p_completion_id UUID,p_reason TEXT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE c task_completions%ROWTYPE; s profiles%ROWTYPE; target_student UUID;
BEGIN
 SELECT student_id INTO target_student FROM task_completions WHERE id=p_completion_id;
 IF NOT FOUND THEN RAISE EXCEPTION '发放记录不存在'; END IF;
 SELECT * INTO s FROM profiles WHERE id=target_student AND role='student' FOR UPDATE;
 IF NOT FOUND OR p_actor_id IS NULL OR s.teacher_id IS DISTINCT FROM p_actor_id
  OR NOT EXISTS(SELECT 1 FROM profiles WHERE id=p_actor_id AND role='teacher') THEN RAISE EXCEPTION '只能撤销本班学生的奖励'; END IF;
 SELECT * INTO c FROM task_completions WHERE id=p_completion_id FOR UPDATE;
 IF NOT FOUND OR c.student_id IS DISTINCT FROM s.id OR c.awarded_by IS DISTINCT FROM p_actor_id THEN RAISE EXCEPTION '只能撤销自己发放的奖励'; END IF;
 IF c.revoked_at IS NOT NULL THEN RETURN jsonb_build_object('balance',s.points,'completion',to_jsonb(c),'alreadyRevoked',true); END IF;
 IF length(trim(COALESCE(p_reason,''))) NOT BETWEEN 1 AND 200 THEN RAISE EXCEPTION '请填写 1 至 200 字的撤销原因'; END IF;
 IF c.points<0 OR (c.points=0 AND c.travel_tickets=0) THEN RAISE EXCEPTION '该记录没有可撤销的奖励'; END IF;
 IF COALESCE(s.points,0)<c.points THEN RAISE EXCEPTION '学生积分余额不足，暂时无法撤销'; END IF;
 IF c.travel_tickets>0 THEN
  UPDATE travel_wallets SET tickets=tickets-c.travel_tickets WHERE user_id=s.id AND tickets>=c.travel_tickets;
  IF NOT FOUND THEN RAISE EXCEPTION '学生旅行券余额不足，暂时无法撤销该奖励'; END IF;
 END IF;
 UPDATE profiles SET points=points-c.points WHERE id=s.id RETURNING * INTO s;
 UPDATE task_completions SET revoked_at=now(),revoked_by=p_actor_id,revoke_reason=trim(p_reason) WHERE id=c.id RETURNING * INTO c;
 RETURN jsonb_build_object('balance',s.points,'completion',to_jsonb(c),'alreadyRevoked',false);
END $$;

REVOKE ALL ON FUNCTION award_task_points(UUID,UUID,UUID,UUID),revoke_task_award(UUID,UUID,TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION award_task_points(UUID,UUID,UUID,UUID),revoke_task_award(UUID,UUID,TEXT) TO anon,authenticated;
CREATE OR REPLACE FUNCTION travel_state(p_user_id UUID) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM profiles WHERE id=p_user_id AND role='student') THEN RAISE EXCEPTION '学生不存在'; END IF;
 RETURN jsonb_build_object(
  'serverNow',now(),
  'canDepart',COALESCE((SELECT tickets FROM travel_wallets WHERE user_id=p_user_id),0)>0 AND NOT EXISTS(SELECT 1 FROM pet_trips WHERE user_id=p_user_id AND claimed_at IS NULL),
  'tickets',COALESCE((SELECT tickets FROM travel_wallets WHERE user_id=p_user_id),0),
  'stamps',COALESCE((SELECT stamps FROM travel_wallets WHERE user_id=p_user_id),0),
  'destinations',(SELECT jsonb_agg(to_jsonb(d) ORDER BY sort_order) FROM travel_destinations d),
  'items',COALESCE((SELECT jsonb_agg(to_jsonb(i)||jsonb_build_object('destination_id',r.destination_id,'stamp_cost',r.stamp_cost,'owned',EXISTS(SELECT 1 FROM user_items u WHERE u.user_id=p_user_id AND u.item_id=i.id)) ORDER BY i.sort_order) FROM travel_rewards r JOIN shop_items i ON i.id=r.item_id),'[]'::jsonb),
  'active',(SELECT to_jsonb(t) FROM pet_trips t WHERE user_id=p_user_id AND claimed_at IS NULL),
  'history',COALESCE((SELECT jsonb_agg(to_jsonb(h) ORDER BY started_at DESC) FROM (SELECT * FROM pet_trips WHERE user_id=p_user_id AND claimed_at IS NOT NULL ORDER BY started_at DESC LIMIT 20) h),'[]'::jsonb),
  'postcards',COALESCE((SELECT jsonb_agg(c) FROM (SELECT DISTINCT destination_id,reward->>'story' AS story FROM pet_trips WHERE user_id=p_user_id AND claimed_at IS NOT NULL) c),'[]'::jsonb)
 );
END $$;

CREATE OR REPLACE FUNCTION start_pet_trip(p_user_id UUID,p_pet_id UUID,p_destination_id TEXT,p_request_id UUID) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE d travel_destinations%ROWTYPE; t pet_trips%ROWTYPE; pet_name_value TEXT;
BEGIN
 PERFORM 1 FROM profiles WHERE id=p_user_id AND role='student' FOR UPDATE;
 IF NOT FOUND OR p_request_id IS NULL THEN RAISE EXCEPTION '无效的出发请求'; END IF;
 SELECT * INTO t FROM pet_trips WHERE id=p_request_id;
 IF FOUND THEN
  IF t.user_id IS DISTINCT FROM p_user_id OR t.pet_id IS DISTINCT FROM p_pet_id OR t.destination_id IS DISTINCT FROM p_destination_id THEN RAISE EXCEPTION '请求编号已被使用'; END IF;
  RETURN to_jsonb(t);
 END IF;
 SELECT name INTO pet_name_value FROM pets WHERE id=p_pet_id AND owner_id=p_user_id FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION '请选择自己的宠物'; END IF;
 IF EXISTS(SELECT 1 FROM pet_trips WHERE user_id=p_user_id AND claimed_at IS NULL) THEN RAISE EXCEPTION '请先等待宠物归来并领取行李'; END IF;
 SELECT * INTO d FROM travel_destinations WHERE id=p_destination_id;
 IF NOT FOUND THEN RAISE EXCEPTION '目的地不存在'; END IF;
 UPDATE travel_wallets SET tickets=tickets-1 WHERE user_id=p_user_id AND tickets>=1;
 IF NOT FOUND THEN RAISE EXCEPTION '旅行券不足，完成老师指定的任务后再来出发吧'; END IF;
 INSERT INTO pet_trips(id,user_id,pet_id,pet_name,destination_id,returns_at,ticket_cost)
 VALUES(p_request_id,p_user_id,p_pet_id,pet_name_value,d.id,now()+make_interval(hours=>d.hours),1) RETURNING * INTO t;
 RETURN to_jsonb(t);
END $$;


COMMIT;

-- 先执行旅行券迁移，再执行本文件；可重复执行。
BEGIN;
CREATE INDEX IF NOT EXISTS pet_trips_user_started_idx ON pet_trips(user_id,started_at DESC,id DESC);
CREATE OR REPLACE FUNCTION teacher_travel_ticket_usage(p_actor_id UUID,p_student_id UUID,p_page INTEGER DEFAULT 1)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE total INTEGER; page_number INTEGER;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM profiles WHERE id=p_actor_id AND role='teacher')
  OR NOT EXISTS(SELECT 1 FROM profiles WHERE id=p_student_id AND role='student' AND teacher_id=p_actor_id)
 THEN RAISE EXCEPTION '只能查看本班学生的旅行券使用记录'; END IF;
 SELECT count(*) INTO total FROM pet_trips WHERE user_id=p_student_id AND ticket_cost>0;
 page_number := LEAST(GREATEST(COALESCE(p_page,1),1),GREATEST(1,(total+9)/10));
 RETURN jsonb_build_object(
  'tickets',COALESCE((SELECT tickets FROM travel_wallets WHERE user_id=p_student_id),0),
  'total',total,'page',page_number,'pageSize',10,
  'entries',COALESCE((SELECT jsonb_agg(to_jsonb(r) ORDER BY r.started_at DESC,r.id DESC) FROM (
    SELECT t.id,t.pet_name,d.name AS destination_name,t.ticket_cost,t.started_at,t.returns_at,
      CASE WHEN t.claimed_at IS NOT NULL THEN 'claimed' WHEN t.returns_at<=now() THEN 'returned' ELSE 'travelling' END AS status
    FROM pet_trips t JOIN travel_destinations d ON d.id=t.destination_id
    WHERE t.user_id=p_student_id AND t.ticket_cost>0
    ORDER BY t.started_at DESC,t.id DESC LIMIT 10 OFFSET (page_number-1)*10
  ) r),'[]'::jsonb)
 );
END $$;
REVOKE ALL ON FUNCTION teacher_travel_ticket_usage(UUID,UUID,INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION teacher_travel_ticket_usage(UUID,UUID,INTEGER) TO anon,authenticated;
COMMIT;

-- 积分使用记录。先部署课堂、商城和奖励撤销迁移；可重复执行。
BEGIN;
CREATE INDEX IF NOT EXISTS feeding_events_student_created_idx ON feeding_events(student_id,created_at DESC);
CREATE OR REPLACE VIEW student_point_spending AS
 SELECT 'feed:'||e.request_id AS id,e.student_id,e.created_at,'feeding'::text AS kind,
  COALESCE(e.result->'pet'->>'name','宠物')||' · '||CASE e.action WHEN 'basic' THEN '普通粮' WHEN 'nice' THEN '营养粮' WHEN 'luxury' THEN '豪华粮' ELSE e.action END AS description,
  (e.result->>'cost')::integer AS cost,(e.result->>'points')::integer AS balance_after,
  e.actor_id
 FROM feeding_events e WHERE (e.result->>'cost')::integer>0
 UNION ALL
 SELECT 'shop:'||o.id,o.buyer_id,o.created_at,'shop',COALESCE(i.name,'装扮商品'),o.price,o.balance_after,o.actor_id
 FROM shop_orders o LEFT JOIN shop_items i ON i.id=o.item_id WHERE o.price>0
 UNION ALL
 SELECT 'revoke:'||c.id,c.student_id,c.revoked_at,'revoke',COALESCE(t.name,'任务奖励')||' · '||COALESCE(c.revoke_reason,'撤销奖励'),c.points,NULL::integer,c.revoked_by
 FROM task_completions c LEFT JOIN tasks t ON t.id=c.task_id WHERE c.revoked_at IS NOT NULL AND c.points>0;
REVOKE ALL ON student_point_spending FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION teacher_point_spending(p_actor_id UUID,p_student_id UUID,p_page INTEGER DEFAULT 1)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE total INTEGER; page_number INTEGER; current_points INTEGER;
BEGIN
 SELECT points INTO current_points FROM profiles WHERE id=p_student_id AND role='student' AND teacher_id=p_actor_id;
 IF NOT FOUND OR NOT EXISTS(SELECT 1 FROM profiles WHERE id=p_actor_id AND role='teacher') THEN RAISE EXCEPTION '只能查看本班学生的积分使用记录'; END IF;
 SELECT count(*) INTO total FROM student_point_spending WHERE student_id=p_student_id;
 page_number:=LEAST(GREATEST(COALESCE(p_page,1),1),GREATEST(1,(total+9)/10));
 RETURN jsonb_build_object('points',COALESCE(current_points,0),'total',total,'page',page_number,'pageSize',10,
  'entries',COALESCE((SELECT jsonb_agg(to_jsonb(r) ORDER BY r.created_at DESC,r.id DESC) FROM (
    SELECT e.id,e.created_at,e.kind,e.description,e.cost,e.balance_after,
      CASE WHEN e.actor_id=p_student_id THEN '学生本人' ELSE COALESCE(a.username,'历史操作人') END AS actor_name,
      CASE WHEN e.actor_id=p_student_id THEN 'student' ELSE COALESCE(a.role,'unknown') END AS actor_role
    FROM student_point_spending e LEFT JOIN profiles a ON a.id=e.actor_id WHERE e.student_id=p_student_id
    ORDER BY e.created_at DESC,e.id DESC LIMIT 10 OFFSET (page_number-1)*10
  ) r),'[]'::jsonb));
END $$;
REVOKE ALL ON FUNCTION teacher_point_spending(UUID,UUID,INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION teacher_point_spending(UUID,UUID,INTEGER) TO anon,authenticated;
COMMIT;

-- 统一积分/旅行券收支记录。先执行课堂、商城和旅行券迁移；可重复执行。
BEGIN;
CREATE OR REPLACE VIEW student_resource_ledger AS
 SELECT 'award:'||c.id AS id,c.student_id,c.created_at,'award'::text AS kind,COALESCE(t.name,'任务奖励') AS description,
 c.points AS points_delta,c.travel_tickets AS tickets_delta,c.awarded_by AS actor_id,NULL::integer AS balance_after
 FROM task_completions c LEFT JOIN tasks t ON t.id=c.task_id WHERE c.points<>0 OR c.travel_tickets<>0
 UNION ALL
 SELECT 'earning:'||e.source_id,e.student_id,e.created_at,'earning',e.reason,e.points,0,e.student_id,NULL::integer
 FROM point_earnings e WHERE NOT EXISTS(SELECT 1 FROM task_completions c WHERE e.source_id='task:'||c.id)
 UNION ALL
 SELECT 'feed:'||e.request_id,e.student_id,e.created_at,'feeding',COALESCE(e.result->'pet'->>'name','宠物')||' · '||CASE e.action WHEN 'basic' THEN '普通粮' WHEN 'nice' THEN '营养粮' WHEN 'luxury' THEN '豪华粮' ELSE e.action END,
 -(e.result->>'cost')::integer,0,e.actor_id,(e.result->>'points')::integer FROM feeding_events e WHERE (e.result->>'cost')::integer>0
 UNION ALL
 SELECT 'shop:'||o.id,o.buyer_id,o.created_at,'shop',COALESCE(i.name,'装扮商品'),-o.price,0,o.actor_id,o.balance_after
 FROM shop_orders o LEFT JOIN shop_items i ON i.id=o.item_id WHERE o.price>0
 UNION ALL
 SELECT 'trip:'||t.id,t.user_id,t.started_at,'travel',t.pet_name||' · '||d.name,0,-t.ticket_cost,t.user_id,NULL::integer
 FROM pet_trips t JOIN travel_destinations d ON d.id=t.destination_id WHERE t.ticket_cost>0
 UNION ALL
 SELECT 'revoke:'||c.id,c.student_id,c.revoked_at,'revoke',COALESCE(t.name,'任务奖励')||' · '||COALESCE(c.revoke_reason,'撤销奖励'),-c.points,-c.travel_tickets,c.revoked_by,NULL::integer
 FROM task_completions c LEFT JOIN tasks t ON t.id=c.task_id WHERE c.revoked_at IS NOT NULL AND (c.points>0 OR c.travel_tickets>0);
REVOKE ALL ON student_resource_ledger FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION teacher_student_ledger(p_actor_id UUID,p_student_id UUID,p_page INTEGER DEFAULT 1)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE total INTEGER; page_number INTEGER; current_points INTEGER;
BEGIN
 SELECT points INTO current_points FROM profiles WHERE id=p_student_id AND role='student' AND teacher_id=p_actor_id;
 IF NOT FOUND OR NOT EXISTS(SELECT 1 FROM profiles WHERE id=p_actor_id AND role='teacher') THEN RAISE EXCEPTION '只能查看本班学生的收支记录'; END IF;
 SELECT count(*) INTO total FROM student_resource_ledger WHERE student_id=p_student_id;
 page_number:=LEAST(GREATEST(COALESCE(p_page,1),1),GREATEST(1,(total+9)/10));
 RETURN jsonb_build_object('points',COALESCE(current_points,0),'tickets',COALESCE((SELECT tickets FROM travel_wallets WHERE user_id=p_student_id),0),
 'total',total,'page',page_number,'pageSize',10,'entries',COALESCE((SELECT jsonb_agg(to_jsonb(r) ORDER BY r.created_at DESC,r.id DESC) FROM (
  SELECT e.id,e.created_at,e.kind,e.description,e.points_delta,e.tickets_delta,e.balance_after,
   CASE WHEN e.actor_id=p_student_id THEN '学生本人' ELSE COALESCE(a.username,'历史操作人') END AS actor_name,
   CASE WHEN e.actor_id=p_student_id THEN 'student' ELSE COALESCE(a.role,'unknown') END AS actor_role
  FROM student_resource_ledger e LEFT JOIN profiles a ON a.id=e.actor_id WHERE e.student_id=p_student_id
  ORDER BY e.created_at DESC,e.id DESC LIMIT 10 OFFSET (page_number-1)*10
 ) r),'[]'::jsonb));
END $$;
REVOKE ALL ON FUNCTION teacher_student_ledger(UUID,UUID,INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION teacher_student_ledger(UUID,UUID,INTEGER) TO anon,authenticated;
COMMIT;
