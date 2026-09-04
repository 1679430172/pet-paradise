-- Allow students in different classes to use the same username.
-- Students in the same teacher-owned class must still have unique usernames.

ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_username_key;

CREATE UNIQUE INDEX IF NOT EXISTS profiles_teacher_username_unique
  ON profiles(username)
  WHERE role = 'teacher';

CREATE UNIQUE INDEX IF NOT EXISTS profiles_student_class_username_unique
  ON profiles(teacher_id, username)
  WHERE role = 'student';

