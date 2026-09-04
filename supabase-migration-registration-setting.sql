-- 管理员控制学生自行注册开关；可重复执行。
-- 默认保持开放，避免升级现有环境后意外关闭注册。
INSERT INTO settings (key, value)
VALUES ('registration_enabled', '{"enabled": true}')
ON CONFLICT (key) DO NOTHING;
