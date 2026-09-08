-- 手动部署清理调度；不要把真实密钥提交到 Git。
-- 先在 Supabase Vault 创建两个 secret：
-- photo_checkins_project_url = https://你的项目.supabase.co（末尾无斜杠）
-- photo_checkins_cleanup_secret = 与 Edge Function 的 PHOTO_CHECKIN_CLEANUP_SECRET 相同的随机密钥
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA pg_catalog;
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;
DO $$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM vault.decrypted_secrets WHERE name='photo_checkins_project_url')
 OR NOT EXISTS(SELECT 1 FROM vault.decrypted_secrets WHERE name='photo_checkins_cleanup_secret') THEN
  RAISE EXCEPTION '请先在 Vault 配置照片清理的项目地址和密钥';
 END IF;
END $$;
-- 同名任务重复执行会更新调度，不创建副本。UTC 19:00 = 北京时间次日 03:00。
SELECT cron.schedule('photo-checkins-daily-cleanup','0 19 * * *',$job$
 SELECT net.http_post(
  url:=(SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name='photo_checkins_project_url' LIMIT 1)||'/functions/v1/photo-checkins',
  headers:=jsonb_build_object('Content-Type','application/json','x-cleanup-secret',
   (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name='photo_checkins_cleanup_secret' LIMIT 1)),
  body:='{"action":"cleanup"}'::jsonb,
  timeout_milliseconds:=120000
 );
$job$);
