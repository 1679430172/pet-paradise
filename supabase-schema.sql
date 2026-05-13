-- ==========================================
-- 班级宠物乐园系统 - Supabase 建表 SQL
-- 不使用 Supabase Auth，纯自定义用户名密码验证
-- 在 Supabase Dashboard → SQL Editor 中执行
-- ==========================================

-- 1. 用户资料表（自定义认证，不依赖 auth.users）
CREATE TABLE profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  username TEXT NOT NULL UNIQUE,
  password TEXT NOT NULL,
  avatar_url TEXT,
  class_name TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 2. 宠物表
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

-- 3. 日记表
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

-- 4. 点赞表
CREATE TABLE likes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  diary_id UUID REFERENCES diary_entries(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, diary_id)
);

-- ==========================================
-- RLS 安全策略（使用 anon key 访问，开放读写）
-- 因为不使用 Supabase Auth，使用简化策略
-- ==========================================

-- profiles
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "允许所有人查看资料"
  ON profiles FOR SELECT
  USING (true);

CREATE POLICY "允许匿名插入资料"
  ON profiles FOR INSERT
  WITH CHECK (true);

CREATE POLICY "允许匿名更新资料"
  ON profiles FOR UPDATE
  USING (true);

-- pets
ALTER TABLE pets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "允许所有人查看宠物"
  ON pets FOR SELECT
  USING (true);

CREATE POLICY "允许匿名创建宠物"
  ON pets FOR INSERT
  WITH CHECK (true);

CREATE POLICY "允许匿名更新宠物"
  ON pets FOR UPDATE
  USING (true);

-- diary_entries
ALTER TABLE diary_entries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "允许查看公开日记或自己的"
  ON diary_entries FOR SELECT
  USING (true);

CREATE POLICY "允许匿名创建日记"
  ON diary_entries FOR INSERT
  WITH CHECK (true);

CREATE POLICY "允许匿名更新日记"
  ON diary_entries FOR UPDATE
  USING (true);

CREATE POLICY "允许匿名删除日记"
  ON diary_entries FOR DELETE
  USING (true);

-- likes
ALTER TABLE likes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "允许所有人查看点赞"
  ON likes FOR SELECT
  USING (true);

CREATE POLICY "允许匿名点赞"
  ON likes FOR INSERT
  WITH CHECK (true);

CREATE POLICY "允许匿名取消点赞"
  ON likes FOR DELETE
  USING (true);

-- ==========================================
-- Storage 存储桶
-- ==========================================

INSERT INTO storage.buckets (id, name, public)
VALUES ('diary-images', 'diary-images', true)
ON CONFLICT (id) DO NOTHING;

-- Storage 策略：允许所有人上传和查看
CREATE POLICY "允许匿名上传图片"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'diary-images');

CREATE POLICY "允许所有人查看图片"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'diary-images');
