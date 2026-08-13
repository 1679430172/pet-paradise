-- 多教师 / 多班级迁移
-- 适用于已经运行过 supabase-schema.sql 的现有数据库。
-- 可重复执行，不会删除现有学生、宠物、日记或积分数据。

BEGIN;

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS teacher_id UUID REFERENCES profiles(id) ON DELETE SET NULL;

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS is_admin BOOLEAN NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS profiles_teacher_id_idx ON profiles(teacher_id);

-- 原有 teacher 账号作为系统管理员，可在教师设置页创建其他老师。
UPDATE profiles
SET is_admin = true
WHERE username = 'teacher' AND role = 'teacher';

-- 原有默认教师补充班级名称。
UPDATE profiles
SET class_name = '默认班级'
WHERE role = 'teacher'
  AND class_name IS NULL;

-- 旧学生统一归属原有 teacher 账号，已有归属关系不会被覆盖。
UPDATE profiles AS student
SET teacher_id = teacher.id,
    class_name = COALESCE(student.class_name, teacher.class_name, '默认班级')
FROM profiles AS teacher
WHERE student.role = 'student'
  AND student.teacher_id IS NULL
  AND teacher.username = 'teacher'
  AND teacher.role = 'teacher';

COMMIT;

-- 执行结果检查：teacher_id 应存在，旧学生应显示对应老师。
SELECT
  student.username AS student_username,
  student.class_name,
  teacher.username AS teacher_username
FROM profiles AS student
LEFT JOIN profiles AS teacher ON teacher.id = student.teacher_id
WHERE student.role = 'student'
ORDER BY student.created_at;
