-- 允许删除已无学生、但仍有关联历史任务/奖励记录的老师。
-- 历史数据保留，老师引用改为 NULL。可重复执行。
BEGIN;

ALTER TABLE tasks DROP CONSTRAINT IF EXISTS tasks_created_by_fkey;
ALTER TABLE tasks
  ADD CONSTRAINT tasks_created_by_fkey
  FOREIGN KEY (created_by) REFERENCES profiles(id) ON DELETE SET NULL;

ALTER TABLE task_completions DROP CONSTRAINT IF EXISTS task_completions_awarded_by_fkey;
ALTER TABLE task_completions
  ADD CONSTRAINT task_completions_awarded_by_fkey
  FOREIGN KEY (awarded_by) REFERENCES profiles(id) ON DELETE SET NULL;

ALTER TABLE task_completions ADD COLUMN IF NOT EXISTS revoked_by UUID;
ALTER TABLE task_completions DROP CONSTRAINT IF EXISTS task_completions_revoked_by_fkey;
ALTER TABLE task_completions
  ADD CONSTRAINT task_completions_revoked_by_fkey
  FOREIGN KEY (revoked_by) REFERENCES profiles(id) ON DELETE SET NULL;

COMMIT;
