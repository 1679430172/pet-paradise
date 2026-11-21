BEGIN;

-- teacher_id is the existing foreign key for the one-class-per-teacher model.
DROP TRIGGER IF EXISTS sync_student_class_name ON public.profiles;
DROP FUNCTION IF EXISTS public.sync_student_class_name();

CREATE OR REPLACE FUNCTION public.sign_in_with_login_log(
  p_username text, p_password text, p_teacher_id uuid, p_access_url text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  matched_profiles jsonb;
  account jsonb;
  login_class_name text;
  headers jsonb := nullif(current_setting('request.headers', true), '')::jsonb;
  client_ip inet;
  access_origin text;
  access_path text;
BEGIN
  SELECT coalesce(jsonb_agg(to_jsonb(p) - 'password'), '[]'::jsonb)
    INTO matched_profiles
  FROM (
    SELECT *
    FROM public.profiles
    WHERE username = p_username AND password = p_password
      AND (p_teacher_id IS NULL OR (role = 'student' AND teacher_id = p_teacher_id))
    LIMIT 2
  ) AS p;

  IF jsonb_array_length(matched_profiles) <> 1 THEN
    RETURN matched_profiles;
  END IF;

  account := matched_profiles -> 0;
  login_class_name := account ->> 'class_name';
  IF account ->> 'role' = 'student' THEN
    SELECT teacher.class_name INTO login_class_name
    FROM public.profiles AS teacher
    WHERE teacher.id = (account ->> 'teacher_id')::uuid
      AND teacher.role = 'teacher';
  END IF;
  IF EXISTS (
    SELECT 1 FROM pet_login_audit.configuration
    WHERE name = 'proxy' AND secret_hash = sha256(convert_to(headers ->> 'x-pet-login-proxy-secret', 'UTF8'))
  ) THEN
    client_ip := (headers ->> 'x-pet-login-client-ip')::inet;
    access_origin := headers ->> 'x-pet-login-origin';
  ELSE
    access_origin := substring(p_access_url FROM '^(https?://[^/?#]+)');
  END IF;

  access_path := substring(p_access_url FROM '^https?://[^/?#]+(/[^?]*)');
  IF access_origin !~ '^https?://([A-Za-z0-9.-]+|\[[0-9A-Fa-f:.]+\])(:[0-9]{1,5})?$' THEN
    access_origin := NULL;
  END IF;

  INSERT INTO pet_login_audit.login_logs (account_id, username, account_role, class_name, client_ip, access_url)
  VALUES (
    (account ->> 'id')::uuid,
    account ->> 'username',
    CASE WHEN (account ->> 'is_admin')::boolean AND account ->> 'role' = 'teacher'
         THEN 'admin' ELSE account ->> 'role' END,
    login_class_name,
    client_ip,
    left(access_origin || coalesce(access_path, '/'), 2048)
  );
  RETURN matched_profiles;
END;
$$;

CREATE OR REPLACE FUNCTION public.reserve_photo_checkin(p_actor uuid,p_id uuid,p_bytes integer,p_description text)
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
 VALUES(p_id,s.id,s.username,s.teacher_id,(SELECT t.class_name FROM profiles t WHERE t.id=s.teacher_id AND t.role='teacher'),p_description,s.id||'/'||p_id||'.jpg',p_bytes) RETURNING * INTO c;
 RETURN c;
END $$;

COMMIT;
