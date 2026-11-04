-- 已部署学生称号功能的数据库执行此增量脚本，允许三个新称号。
CREATE OR REPLACE FUNCTION teacher_set_student_title(
  p_actor_id UUID,
  p_student_id UUID,
  p_title TEXT
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  normalized_title TEXT := NULLIF(btrim(p_title), '');
BEGIN
  IF normalized_title IS NOT NULL AND normalized_title NOT IN (
    '进步之星', '自律达人', '热心伙伴', '勇敢挑战者', '坚持小标兵', '课堂闪耀之星',
    '全勤宝贝', '妙笔小达人', '跳绳小健将'
  ) THEN
    RAISE EXCEPTION '不支持的称号';
  END IF;

  UPDATE profiles
  SET current_title = normalized_title
  WHERE id = p_student_id
    AND role = 'student'
    AND teacher_id = p_actor_id
    AND EXISTS (
      SELECT 1 FROM profiles actor
      WHERE actor.id = p_actor_id AND actor.role = 'teacher'
    );

  IF NOT FOUND THEN
    RAISE EXCEPTION '只能给本班学生佩戴称号';
  END IF;
  RETURN jsonb_build_object('title', normalized_title);
END;
$$;
