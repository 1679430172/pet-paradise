-- ==========================================
-- 迁移脚本：从 Supabase Auth 模式迁移到自定义认证
-- 如果你之前已经执行过旧的 supabase-schema.sql，
-- 请在 Supabase Dashboard → SQL Editor 中执行本脚本
-- ==========================================

-- 步骤 1：删除旧的触发器和函数
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS handle_new_user();

-- 步骤 2：删除旧的 RLS 策略
DROP POLICY IF EXISTS "所有人可查看资料" ON profiles;
DROP POLICY IF EXISTS "用户可创建自己的资料" ON profiles;
DROP POLICY IF EXISTS "用户可更新自己的资料" ON profiles;
DROP POLICY IF EXISTS "所有人可查看宠物" ON pets;
DROP POLICY IF EXISTS "用户可创建自己的宠物" ON pets;
DROP POLICY IF EXISTS "用户可更新自己的宠物" ON pets;
DROP POLICY IF EXISTS "可查看自己的或公开的日记" ON diary_entries;
DROP POLICY IF EXISTS "用户可创建自己的日记" ON diary_entries;
DROP POLICY IF EXISTS "用户可更新自己的日记" ON diary_entries;
DROP POLICY IF EXISTS "用户可删除自己的日记" ON diary_entries;
DROP POLICY IF EXISTS "所有人可查看点赞" ON likes;
DROP POLICY IF EXISTS "用户可点赞" ON likes;
DROP POLICY IF EXISTS "用户可取消点赞" ON likes;
DROP POLICY IF EXISTS "用户可上传图片" ON storage.objects;
DROP POLICY IF EXISTS "所有人可查看图片" ON storage.objects;

-- 步骤 3：删除旧表（注意：会丢失所有旧数据！）
DROP TABLE IF EXISTS likes CASCADE;
DROP TABLE IF EXISTS diary_entries CASCADE;
DROP TABLE IF EXISTS pets CASCADE;
DROP TABLE IF EXISTS profiles CASCADE;

-- 步骤 4：重建 profiles 表（不再引用 auth.users）
CREATE TABLE profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  username TEXT NOT NULL UNIQUE,
  password TEXT NOT NULL,
  avatar_url TEXT,
  class_name TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 步骤 5：重建其他表
CREATE TABLE pets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID REFERENCES profiles(id) ON DELETE CASCADE UNIQUE,
  name TEXT NOT NULL,
  species TEXT NOT NULL,
  appearance JSONB DEFAULT '{}',
  level INTEGER DEFAULT 1,
  xp INTEGER DEFAULT 0,
  hunger INTEGER DEFAULT 100,
  happiness INTEGER DEFAULT 100,
  cleanliness INTEGER DEFAULT 100,
  last_fed_at TIMESTAMPTZ,
  last_played_at TIMESTAMPTZ,
  last_cleaned_at TIMESTAMPTZ,
  badges JSONB DEFAULT '["first_pet"]',
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE diary_entries (
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

CREATE TABLE likes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  diary_id UUID REFERENCES diary_entries(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, diary_id)
);

-- 步骤 6：设置新的 RLS 策略（开放式，因为不使用 Supabase Auth）
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "允许所有人查看资料" ON profiles FOR SELECT USING (true);
CREATE POLICY "允许匿名插入资料" ON profiles FOR INSERT WITH CHECK (true);
CREATE POLICY "允许匿名更新资料" ON profiles FOR UPDATE USING (true);

ALTER TABLE pets ENABLE ROW LEVEL SECURITY;
CREATE POLICY "允许所有人查看宠物" ON pets FOR SELECT USING (true);
CREATE POLICY "允许匿名创建宠物" ON pets FOR INSERT WITH CHECK (true);
CREATE POLICY "允许匿名更新宠物" ON pets FOR UPDATE USING (true);

ALTER TABLE diary_entries ENABLE ROW LEVEL SECURITY;
CREATE POLICY "允许查看日记" ON diary_entries FOR SELECT USING (true);
CREATE POLICY "允许匿名创建日记" ON diary_entries FOR INSERT WITH CHECK (true);
CREATE POLICY "允许匿名更新日记" ON diary_entries FOR UPDATE USING (true);
CREATE POLICY "允许匿名删除日记" ON diary_entries FOR DELETE USING (true);

ALTER TABLE likes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "允许所有人查看点赞" ON likes FOR SELECT USING (true);
CREATE POLICY "允许匿名点赞" ON likes FOR INSERT WITH CHECK (true);
CREATE POLICY "允许匿名取消点赞" ON likes FOR DELETE USING (true);

-- 步骤 7：Storage（如果之前已创建则跳过）
INSERT INTO storage.buckets (id, name, public)
VALUES ('diary-images', 'diary-images', true)
ON CONFLICT (id) DO NOTHING;

-- 删除旧 storage 策略后创建新的
DROP POLICY IF EXISTS "允许匿名上传图片" ON storage.objects;
DROP POLICY IF EXISTS "允许所有人查看图片" ON storage.objects;

CREATE POLICY "允许匿名上传图片"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'diary-images');

CREATE POLICY "允许所有人查看图片"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'diary-images');
