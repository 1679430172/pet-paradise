-- 学生修改自己的密码；教师重置自己班级学生的密码。
-- 项目使用自定义登录，因此 actor_id 延续现有业务身份校验模型。
BEGIN;

CREATE OR REPLACE FUNCTION change_student_password(
  p_actor_id UUID, p_current_password TEXT, p_new_password TEXT
) RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF p_actor_id IS NULL OR COALESCE(p_current_password,'')='' OR COALESCE(p_new_password,'')='' THEN
    RAISE EXCEPTION '密码参数不完整';
  END IF;
  IF NOT EXISTS(
    SELECT 1 FROM profiles
    WHERE id=p_actor_id AND role='student' AND password=p_current_password
  ) THEN RAISE EXCEPTION '当前密码不正确'; END IF;
  UPDATE profiles SET password=p_new_password WHERE id=p_actor_id AND role='student';
  RETURN true;
END $$;

CREATE OR REPLACE FUNCTION teacher_reset_student_password(
  p_actor_id UUID, p_student_id UUID, p_new_password TEXT
) RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF p_actor_id IS NULL OR p_student_id IS NULL OR COALESCE(p_new_password,'')='' THEN
    RAISE EXCEPTION '密码参数不完整';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM profiles WHERE id=p_actor_id AND role='teacher')
    OR NOT EXISTS(SELECT 1 FROM profiles WHERE id=p_student_id AND role='student' AND teacher_id=p_actor_id) THEN
    RAISE EXCEPTION '只能重置自己班级学生的密码';
  END IF;
  UPDATE profiles SET password=p_new_password WHERE id=p_student_id;
  RETURN true;
END $$;

GRANT EXECUTE ON FUNCTION change_student_password(UUID,TEXT,TEXT),teacher_reset_student_password(UUID,UUID,TEXT) TO anon,authenticated;
COMMIT;
