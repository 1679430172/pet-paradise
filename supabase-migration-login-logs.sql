BEGIN;

CREATE SCHEMA IF NOT EXISTS pet_login_audit;
REVOKE ALL ON SCHEMA pet_login_audit FROM PUBLIC, anon, authenticated;

CREATE TABLE IF NOT EXISTS pet_login_audit.configuration (
  name text PRIMARY KEY,
  secret_hash bytea NOT NULL CHECK (octet_length(secret_hash) = 32)
);

CREATE TABLE IF NOT EXISTS pet_login_audit.administrators (
  auth_user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS pet_login_audit.login_logs (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  account_id uuid NOT NULL,
  username text NOT NULL,
  account_role text NOT NULL,
  class_name text,
  client_ip inet,
  access_url text,
  logged_in_at timestamptz NOT NULL DEFAULT now()
);

REVOKE ALL ON ALL TABLES IN SCHEMA pet_login_audit FROM PUBLIC, anon, authenticated;

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

DROP FUNCTION IF EXISTS public.read_login_logs(text, bigint);
DELETE FROM pet_login_audit.configuration WHERE name = 'viewer';

CREATE OR REPLACE FUNCTION public.read_login_logs(p_before_id bigint)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
DECLARE
  matching_logs jsonb;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pet_login_audit.administrators
    WHERE auth_user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION '当前会话没有登录日志查看权限' USING ERRCODE = '42501';
  END IF;

  SELECT coalesce(jsonb_agg(to_jsonb(log) ORDER BY log.id DESC), '[]'::jsonb)
    INTO matching_logs
  FROM (
    SELECT id, username, account_role, class_name, host(client_ip) AS client_ip, access_url, logged_in_at
    FROM pet_login_audit.login_logs
    WHERE p_before_id IS NULL OR id < p_before_id
    ORDER BY id DESC
    LIMIT 51
  ) AS log;
  RETURN matching_logs;
END;
$$;

REVOKE ALL ON FUNCTION public.sign_in_with_login_log(text, text, uuid, text),
  public.read_login_logs(bigint) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.sign_in_with_login_log(text, text, uuid, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.read_login_logs(bigint) TO authenticated;

COMMIT;
