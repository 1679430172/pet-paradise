-- 公告定时开始；旧公告保留 NULL，继续立即生效。
BEGIN;

ALTER TABLE public.announcements
  ADD COLUMN IF NOT EXISTS start_at TIMESTAMPTZ;

ALTER TABLE public.announcements
  DROP CONSTRAINT IF EXISTS announcements_time_range;
ALTER TABLE public.announcements
  ADD CONSTRAINT announcements_time_range
  CHECK (start_at IS NULL OR end_at IS NULL OR end_at > start_at);

COMMIT;
