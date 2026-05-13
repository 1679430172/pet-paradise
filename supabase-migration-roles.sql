-- ==========================================
-- 师生分端迁移 SQL
-- 在 Supabase Dashboard → SQL Editor 中执行
-- ==========================================

-- 1. profiles 表加列
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'student';
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS points INTEGER DEFAULT 0;

-- 2. 系统配置表
CREATE TABLE IF NOT EXISTS settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key TEXT UNIQUE NOT NULL,
  value JSONB NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "允许读取设置" ON settings FOR SELECT USING (true);
CREATE POLICY "允许修改设置" ON settings FOR UPDATE USING (true);
CREATE POLICY "允许插入设置" ON settings FOR INSERT WITH CHECK (true);

-- 预置积分消耗配置
INSERT INTO settings (key, value)
VALUES ('action_costs', '{"feed": 5, "play": 8, "clean": 3}')
ON CONFLICT (key) DO NOTHING;

-- 预置日记积分奖励配置（每天第一篇日记奖励积分）
INSERT INTO settings (key, value)
VALUES ('diary_points', '{"points": 5}')
ON CONFLICT (key) DO NOTHING;

-- 3. 任务定义表
CREATE TABLE IF NOT EXISTS tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  points INTEGER NOT NULL,
  is_active BOOLEAN DEFAULT true,
  created_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "允许读取任务" ON tasks FOR SELECT USING (true);
CREATE POLICY "允许创建任务" ON tasks FOR INSERT WITH CHECK (true);
CREATE POLICY "允许修改任务" ON tasks FOR UPDATE USING (true);
CREATE POLICY "允许删除任务" ON tasks FOR DELETE USING (true);

-- 4. 任务完成记录表
CREATE TABLE IF NOT EXISTS task_completions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id UUID REFERENCES tasks(id),
  student_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  awarded_by UUID REFERENCES profiles(id),
  points INTEGER NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE task_completions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "允许读取完成记录" ON task_completions FOR SELECT USING (true);
CREATE POLICY "允许插入完成记录" ON task_completions FOR INSERT WITH CHECK (true);

-- 5. 预置教师账号
-- 密码为 "teacher123" 经 SHA-256('teacher123' + 'pet-paradise-salt') 哈希
INSERT INTO profiles (username, password, role, points)
VALUES (
  'teacher',
  'a33adec4a7b141ebd5ee6d40cade33697f7c91962cb4d269eac033ebefce50c9',
  'teacher',
  0
)
ON CONFLICT (username) DO UPDATE SET role = 'teacher';

-- 教师账号：用户名 teacher，密码 teacher123

-- 6. 给 profiles 表添加 DELETE 策略（教师可删除学生）
CREATE POLICY "允许删除学生" ON profiles FOR DELETE USING (true);
