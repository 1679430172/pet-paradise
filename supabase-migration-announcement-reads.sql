BEGIN;

CREATE TABLE IF NOT EXISTS public.announcement_reads (
  announcement_id uuid NOT NULL REFERENCES public.announcements(id) ON DELETE CASCADE,
  account_id uuid NOT NULL,
  username text NOT NULL,
  account_role text NOT NULL,
  class_name text,
  read_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (announcement_id, account_id)
);
ALTER TABLE public.announcement_reads ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.announcement_reads FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.confirm_announcement_read(p_announcement_id uuid, p_session_token text)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
    INSERT INTO public.announcement_reads (announcement_id, account_id, username, account_role, class_name)
    SELECT a.id, p.id, p.username, p.role, teacher.class_name
    FROM public.photo_checkin_sessions AS s
    JOIN public.profiles AS p ON p.id = s.profile_id AND p.password = s.password_hash
    CROSS JOIN public.announcements AS a
    LEFT JOIN public.profiles AS teacher
      ON teacher.id = CASE WHEN p.role = 'teacher' THEN p.id ELSE p.teacher_id END
      AND teacher.role = 'teacher'
    WHERE s.token_hash = encode(sha256(convert_to(p_session_token, 'UTF8')), 'hex')
      AND s.expires_at > now()
      AND p.is_admin IS NOT TRUE
      AND a.id = p_announcement_id AND a.enabled
      AND (a.start_at IS NULL OR a.start_at <= now())
      AND (a.end_at IS NULL OR a.end_at > now())
      AND (NOT a.teachers_only OR p.role = 'teacher')
      AND (a.target_class_ids IS NULL
        OR (CASE WHEN p.role = 'teacher' THEN p.id ELSE p.teacher_id END) = ANY(a.target_class_ids))
    ON CONFLICT (announcement_id, account_id) DO NOTHING;

  RETURN FOUND OR EXISTS (
      SELECT 1 FROM public.announcement_reads AS r
      JOIN public.photo_checkin_sessions AS s ON s.profile_id = r.account_id
      JOIN public.profiles AS p ON p.id = s.profile_id AND p.password = s.password_hash
      WHERE r.announcement_id = p_announcement_id AND s.expires_at > now()
        AND s.token_hash = encode(sha256(convert_to(p_session_token, 'UTF8')), 'hex')
    );
END;
$$;

CREATE OR REPLACE FUNCTION public.read_announcement_receipts(p_announcement_id uuid, p_after_account_id uuid DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pet_login_audit.administrators WHERE auth_user_id = auth.uid()) THEN
    RAISE EXCEPTION '当前会话没有公告已读记录查看权限' USING ERRCODE = '42501';
  END IF;

  RETURN (
    SELECT coalesce(jsonb_agg(to_jsonb(receipt) ORDER BY receipt.account_id), '[]'::jsonb)
    FROM (
      SELECT account_id, username, account_role, class_name, read_at
      FROM public.announcement_reads
      WHERE announcement_id = p_announcement_id
        AND (p_after_account_id IS NULL OR account_id > p_after_account_id)
      ORDER BY account_id
      LIMIT 51
    ) AS receipt
  );
END;
$$;

REVOKE ALL ON FUNCTION public.confirm_announcement_read(uuid, text),
  public.read_announcement_receipts(uuid, uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_announcement_read(uuid, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.read_announcement_receipts(uuid, uuid) TO authenticated;

COMMIT;
