-- 公告记录、自动结束时间与历史记录。
CREATE TABLE IF NOT EXISTS announcements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type TEXT NOT NULL DEFAULT 'notice' CHECK (type IN ('notice', 'celebration', 'reminder', 'maintenance', 'other')),
  title TEXT NOT NULL CHECK (char_length(title) BETWEEN 1 AND 50),
  content TEXT NOT NULL CHECK (char_length(content) <= 1000),
  enabled BOOLEAN NOT NULL DEFAULT true,
  end_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE announcements ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "允许读取公告" ON announcements;
DROP POLICY IF EXISTS "允许创建公告" ON announcements;
DROP POLICY IF EXISTS "允许修改公告" ON announcements;
CREATE POLICY "允许读取公告" ON announcements FOR SELECT USING (true);
CREATE POLICY "允许创建公告" ON announcements FOR INSERT WITH CHECK (true);
CREATE POLICY "允许修改公告" ON announcements FOR UPDATE USING (true);

-- 将旧版 settings 中的公告保留为首条历史记录。
INSERT INTO announcements (type, title, content, enabled, end_at, created_at)
SELECT
  CASE WHEN value->>'type' IN ('notice', 'celebration', 'reminder', 'maintenance', 'other') THEN value->>'type' ELSE 'notice' END,
  COALESCE(NULLIF(value->>'title', ''), '系统公告'),
  COALESCE(value->>'content', ''),
  COALESCE((value->>'enabled')::boolean, false),
  NULL,
  COALESCE(updated_at, now())
FROM settings
WHERE key = 'announcement'
  AND NOT EXISTS (SELECT 1 FROM announcements);
