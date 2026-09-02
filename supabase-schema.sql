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
ON CONFLICT (username) DO UPDATE SET role = 'teacher';

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
