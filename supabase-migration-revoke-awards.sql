-- 已部署课堂事务功能的项目执行；可重复执行。先迁移数据库，再发布前端。
BEGIN;
ALTER TABLE task_completions ADD COLUMN IF NOT EXISTS revoked_at TIMESTAMPTZ;
ALTER TABLE task_completions ADD COLUMN IF NOT EXISTS revoked_by UUID REFERENCES profiles(id);
ALTER TABLE task_completions ADD COLUMN IF NOT EXISTS revoke_reason TEXT;
-- 延续原项目的开放 RLS；撤销 RPC 使用调用者权限，需要允许写撤销元信息。
DROP POLICY IF EXISTS "允许撤销任务奖励" ON task_completions;
CREATE POLICY "允许撤销任务奖励" ON task_completions FOR UPDATE USING (true) WITH CHECK (true);
GRANT UPDATE (revoked_at, revoked_by, revoke_reason) ON task_completions TO anon, authenticated;

CREATE OR REPLACE FUNCTION revoke_task_award(p_actor_id UUID, p_completion_id UUID, p_reason TEXT)
RETURNS JSONB LANGUAGE plpgsql SECURITY INVOKER SET search_path = public AS $$
DECLARE c task_completions%ROWTYPE; s profiles%ROWTYPE; target_student UUID;
BEGIN
  SELECT student_id INTO target_student FROM task_completions WHERE id = p_completion_id;
  IF NOT FOUND THEN RAISE EXCEPTION '发放记录不存在'; END IF;
  -- 和喂食、发奖保持相同锁顺序，避免并发覆盖余额。
  SELECT * INTO s FROM profiles WHERE id = target_student AND role = 'student' FOR UPDATE;
  IF NOT FOUND OR p_actor_id IS NULL OR s.teacher_id IS DISTINCT FROM p_actor_id
    OR NOT EXISTS(SELECT 1 FROM profiles WHERE id = p_actor_id AND role = 'teacher') THEN
    RAISE EXCEPTION '只能撤销本班学生的奖励';
  END IF;
  SELECT * INTO c FROM task_completions WHERE id = p_completion_id FOR UPDATE;
  IF NOT FOUND OR c.student_id IS DISTINCT FROM s.id OR c.awarded_by IS DISTINCT FROM p_actor_id THEN
    RAISE EXCEPTION '只能撤销自己发放的奖励';
  END IF;
  -- 以原发奖记录为幂等键，丢失响应后的重试也不重复扣分。
  IF c.revoked_at IS NOT NULL THEN
    RETURN jsonb_build_object('balance',s.points,'completion',to_jsonb(c),'alreadyRevoked',true);
  END IF;
  IF length(trim(COALESCE(p_reason,''))) NOT BETWEEN 1 AND 200 THEN
    RAISE EXCEPTION '请填写 1 至 200 字的撤销原因';
  END IF;
  IF c.points <= 0 THEN RAISE EXCEPTION '该记录不是正积分奖励，无法撤销'; END IF;
  IF COALESCE(s.points,0) < c.points THEN
    RAISE EXCEPTION '学生当前余额为 % 分，不足以收回 % 分，暂时无法撤销', COALESCE(s.points,0),c.points;
  END IF;
  UPDATE profiles SET points = points - c.points WHERE id = s.id RETURNING * INTO s;
  IF NOT FOUND THEN RAISE EXCEPTION '余额更新失败，未撤销奖励'; END IF;
  UPDATE task_completions SET revoked_at = now(), revoked_by = p_actor_id, revoke_reason = trim(p_reason)
    WHERE id = c.id RETURNING * INTO c;
  IF NOT FOUND THEN RAISE EXCEPTION '撤销记录写入失败，积分未扣除'; END IF;
  RETURN jsonb_build_object('balance',s.points,'completion',to_jsonb(c),'alreadyRevoked',false);
END $$;

CREATE OR REPLACE FUNCTION teacher_award_total(p_teacher_id UUID)
RETURNS BIGINT LANGUAGE sql STABLE SECURITY INVOKER SET search_path = public AS $$
  SELECT COALESCE(sum(points),0) FROM task_completions WHERE awarded_by = p_teacher_id AND revoked_at IS NULL;
$$;

CREATE OR REPLACE FUNCTION weekly_leaderboard(p_teacher_id UUID)
RETURNS JSONB LANGUAGE sql STABLE SECURITY INVOKER SET search_path = public AS $$
  WITH period AS (
    SELECT date_trunc('week',now() AT TIME ZONE 'Asia/Shanghai') AT TIME ZONE 'Asia/Shanghai' AS start_at
  ), totals AS (
    SELECT p.id,p.username,COALESCE(sum(e.points),0) AS points
    FROM profiles p CROSS JOIN period w
    LEFT JOIN point_earnings e ON e.student_id = p.id AND e.teacher_id = p_teacher_id
      AND e.created_at >= w.start_at AND e.created_at < w.start_at + interval '7 days'
      AND NOT EXISTS (SELECT 1 FROM task_completions c WHERE 'task:' || c.id = e.source_id AND c.revoked_at IS NOT NULL)
    WHERE p.teacher_id = p_teacher_id AND p.role = 'student'
    GROUP BY p.id,p.username
  ), ranked AS (
    SELECT t.*,CASE WHEN t.points > 0 THEN dense_rank() OVER (ORDER BY t.points DESC) ELSE NULL END AS rank,
      COALESCE(pet.level,0) AS pet_level,COALESCE(pet.name,'未领养') AS pet_name
    FROM totals t LEFT JOIN LATERAL (
      SELECT name,level FROM pets WHERE owner_id = t.id ORDER BY level DESC,created_at,id LIMIT 1
    ) pet ON true
  ) SELECT jsonb_build_object('weekStart',w.start_at,'weekEnd',w.start_at + interval '7 days',
    'entries',COALESCE((SELECT jsonb_agg(to_jsonb(r) ORDER BY r.points DESC,r.username,r.id) FROM ranked r),'[]'::JSONB))
  FROM period w;
$$;
GRANT EXECUTE ON FUNCTION revoke_task_award(UUID,UUID,TEXT), teacher_award_total(UUID) TO anon, authenticated;
COMMIT;
