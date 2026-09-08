-- 自主照片打卡；先执行 supabase-schema.sql / 课堂积分迁移。
-- 表和 RPC 仅供 photo-checkins Edge Function 的 service_role 使用。
BEGIN;
CREATE TABLE IF NOT EXISTS photo_checkins (
 id uuid PRIMARY KEY,
 student_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
 student_name text NOT NULL,
 teacher_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
 class_name text,
 description text NOT NULL DEFAULT '' CHECK (length(description)<=200),
 object_path text NOT NULL UNIQUE,
 bytes integer NOT NULL CHECK (bytes BETWEEN 1 AND 204800),
 status text NOT NULL DEFAULT 'uploading' CHECK (status IN ('uploading','pending','awarded','rejected','expired','failed')),
 points integer NOT NULL DEFAULT 0 CHECK (points BETWEEN 0 AND 10000),
 feedback text NOT NULL DEFAULT '' CHECK (length(feedback)<=200),
 created_at timestamptz NOT NULL DEFAULT now(),
 submitted_at timestamptz,
 submission_day date,
 reviewed_at timestamptz,
 expires_at timestamptz NOT NULL DEFAULT now()+interval '1 hour',
 photo_deleted_at timestamptz
);
CREATE INDEX IF NOT EXISTS photo_checkins_student_day ON photo_checkins(student_id,submission_day);
CREATE INDEX IF NOT EXISTS photo_checkins_teacher_date ON photo_checkins(teacher_id,created_at DESC,id);
CREATE INDEX IF NOT EXISTS photo_checkins_cleanup ON photo_checkins(expires_at) WHERE photo_deleted_at IS NULL;
CREATE TABLE IF NOT EXISTS photo_checkin_sessions (
 token_hash text PRIMARY KEY, profile_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
 password_hash text NOT NULL, expires_at timestamptz NOT NULL
);
CREATE TABLE IF NOT EXISTS photo_checkin_login_limits (
 profile_id uuid PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
 attempts integer NOT NULL DEFAULT 0, window_start timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS photo_checkin_settings (
 id boolean PRIMARY KEY DEFAULT true CHECK(id), max_bytes bigint NOT NULL CHECK(max_bytes>0)
);
INSERT INTO photo_checkin_settings VALUES(true,650000000) ON CONFLICT DO NOTHING;
ALTER TABLE photo_checkins ENABLE ROW LEVEL SECURITY;
ALTER TABLE photo_checkin_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE photo_checkin_login_limits ENABLE ROW LEVEL SECURITY;
ALTER TABLE photo_checkin_settings ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON photo_checkins,photo_checkin_sessions,photo_checkin_settings,photo_checkin_login_limits FROM PUBLIC,anon,authenticated;
GRANT ALL ON photo_checkins,photo_checkin_sessions,photo_checkin_settings,photo_checkin_login_limits TO service_role;

INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
 VALUES('photo-checkins','photo-checkins',false,204800,ARRAY['image/jpeg'])
 ON CONFLICT(id) DO UPDATE SET public=false,file_size_limit=204800,allowed_mime_types=ARRAY['image/jpeg'];

CREATE OR REPLACE FUNCTION photo_checkin_login_attempt(p_profile uuid)
RETURNS boolean LANGUAGE plpgsql SET search_path=public AS $$
DECLARE n integer;
BEGIN
 INSERT INTO photo_checkin_login_limits(profile_id,attempts) VALUES(p_profile,1)
 ON CONFLICT(profile_id) DO UPDATE SET
 attempts=CASE WHEN photo_checkin_login_limits.window_start<now()-interval '15 minutes' THEN 1 ELSE photo_checkin_login_limits.attempts+1 END,
 window_start=CASE WHEN photo_checkin_login_limits.window_start<now()-interval '15 minutes' THEN now() ELSE photo_checkin_login_limits.window_start END
 RETURNING attempts INTO n;
 RETURN n<=10;
END $$;

CREATE OR REPLACE FUNCTION reserve_photo_checkin(p_actor uuid,p_id uuid,p_bytes integer,p_description text)
RETURNS photo_checkins LANGUAGE plpgsql SET search_path=public AS $$
DECLARE s profiles%ROWTYPE; c photo_checkins%ROWTYPE; cap bigint; used bigint; n integer;
BEGIN
 -- 全局容量锁同时串行化每日名额预留，上传文件前先预留容量。
 SELECT max_bytes INTO cap FROM photo_checkin_settings WHERE id=true FOR UPDATE;
 SELECT * INTO s FROM profiles WHERE id=p_actor AND role='student' FOR UPDATE;
 IF NOT FOUND OR s.teacher_id IS NULL THEN RAISE EXCEPTION '请先加入班级'; END IF;
 SELECT * INTO c FROM photo_checkins WHERE id=p_id;
 IF FOUND THEN
  IF c.student_id IS DISTINCT FROM p_actor OR c.bytes IS DISTINCT FROM p_bytes OR c.description IS DISTINCT FROM p_description THEN RAISE EXCEPTION '提交编号已被使用'; END IF;
  RETURN c;
 END IF;
 SELECT count(*) INTO n FROM photo_checkins WHERE student_id=p_actor AND
 (submission_day=(now() AT TIME ZONE 'Asia/Shanghai')::date OR (status='uploading' AND expires_at>now()));
 IF n>=3 THEN RAISE EXCEPTION '今天已上传三张照片，请明天再来'; END IF;
 SELECT COALESCE(sum(bytes),0) INTO used FROM photo_checkins WHERE photo_deleted_at IS NULL;
 IF used+p_bytes>cap THEN RAISE EXCEPTION '照片存储空间暂时不足，请稍后再试'; END IF;
 INSERT INTO photo_checkins(id,student_id,student_name,teacher_id,class_name,description,object_path,bytes)
 VALUES(p_id,s.id,s.username,s.teacher_id,s.class_name,p_description,s.id||'/'||p_id||'.jpg',p_bytes) RETURNING * INTO c;
 RETURN c;
END $$;

CREATE OR REPLACE FUNCTION finish_photo_checkin(p_actor uuid,p_id uuid)
RETURNS photo_checkins LANGUAGE plpgsql SET search_path=public AS $$
DECLARE c photo_checkins%ROWTYPE; n integer;
BEGIN
 PERFORM 1 FROM photo_checkin_settings WHERE id=true FOR UPDATE;
 SELECT * INTO c FROM photo_checkins WHERE id=p_id AND student_id=p_actor FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION '打卡不存在'; END IF;
 IF c.submitted_at IS NOT NULL THEN RETURN c; END IF;
 IF c.status<>'uploading' OR c.expires_at<=now() THEN RAISE EXCEPTION '上传已过期，请重新提交'; END IF;
 SELECT count(*) INTO n FROM photo_checkins WHERE student_id=p_actor AND submission_day=(now() AT TIME ZONE 'Asia/Shanghai')::date;
 IF n>=3 THEN RAISE EXCEPTION '今天已上传三张照片'; END IF;
 UPDATE photo_checkins SET status='pending',submitted_at=now(),submission_day=(now() AT TIME ZONE 'Asia/Shanghai')::date,
 expires_at=now()+interval '15 days' WHERE id=p_id RETURNING * INTO c;
 RETURN c;
END $$;

CREATE OR REPLACE FUNCTION review_photo_checkin(p_actor uuid,p_id uuid,p_points integer,p_feedback text)
RETURNS photo_checkins LANGUAGE plpgsql SET search_path=public AS $$
DECLARE c photo_checkins%ROWTYPE; target uuid;
BEGIN
 IF p_points IS NULL OR p_points<0 OR p_points>10000 OR p_feedback IS NULL OR length(p_feedback)>200 THEN RAISE EXCEPTION '请输入 0 至 10000 的整数积分，反馈不超过 200 字'; END IF;
 SELECT student_id INTO target FROM photo_checkins WHERE id=p_id;
 -- 和现有奖励/喂食采用相同的学生余额锁。
 PERFORM 1 FROM profiles WHERE id=target AND role='student' AND teacher_id=p_actor FOR UPDATE;
 IF NOT FOUND OR NOT EXISTS(SELECT 1 FROM profiles WHERE id=p_actor AND role='teacher' AND NOT is_admin) THEN RAISE EXCEPTION '只能审核本班学生的打卡'; END IF;
 SELECT * INTO c FROM photo_checkins WHERE id=p_id AND teacher_id=p_actor FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION '打卡不存在'; END IF;
 IF c.status IN ('awarded','rejected') THEN
  IF c.points<>p_points OR c.feedback<>p_feedback THEN RAISE EXCEPTION '该照片已审核，请刷新查看'; END IF;
  RETURN c;
 END IF;
 IF c.status<>'pending' OR c.expires_at<=now() THEN RAISE EXCEPTION '该打卡已过期或不能审核'; END IF;
 IF p_points>0 THEN
  UPDATE profiles SET points=COALESCE(points,0)+p_points WHERE id=target;
  INSERT INTO task_completions(id,task_id,student_id,awarded_by,points) VALUES(p_id,NULL,target,p_actor,p_points);
  INSERT INTO point_earnings(source_id,student_id,teacher_id,points,reason) VALUES('task:'||p_id,target,p_actor,p_points,'自主照片打卡');
 END IF;
 UPDATE photo_checkins SET status=CASE WHEN p_points>0 THEN 'awarded' ELSE 'rejected' END,
 points=p_points,feedback=p_feedback,reviewed_at=now(),expires_at=now()+interval '7 days' WHERE id=p_id RETURNING * INTO c;
 RETURN c;
END $$;

CREATE OR REPLACE FUNCTION claim_expired_photo_checkins()
RETURNS SETOF photo_checkins LANGUAGE plpgsql SET search_path=public AS $$
BEGIN
 RETURN QUERY UPDATE photo_checkins SET status=CASE WHEN status='pending' THEN 'expired' WHEN status='uploading' THEN 'failed' ELSE status END
 WHERE id IN (SELECT id FROM photo_checkins WHERE expires_at<=now() AND photo_deleted_at IS NULL ORDER BY expires_at LIMIT 100 FOR UPDATE SKIP LOCKED)
 RETURNING *;
END $$;
REVOKE ALL ON FUNCTION photo_checkin_login_attempt(uuid),reserve_photo_checkin(uuid,uuid,integer,text),finish_photo_checkin(uuid,uuid),review_photo_checkin(uuid,uuid,integer,text),claim_expired_photo_checkins() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION photo_checkin_login_attempt(uuid),reserve_photo_checkin(uuid,uuid,integer,text),finish_photo_checkin(uuid,uuid),review_photo_checkin(uuid,uuid,integer,text),claim_expired_photo_checkins() TO service_role;
COMMIT;
