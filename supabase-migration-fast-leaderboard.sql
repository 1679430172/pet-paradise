-- Run once in Supabase SQL Editor before publishing the matching frontend.
-- The function is idempotent and keeps reward-only, revoked-task and deterministic-rank semantics.
BEGIN;

CREATE OR REPLACE FUNCTION period_leaderboard(
  p_teacher_id UUID,
  p_start TIMESTAMPTZ DEFAULT NULL,
  p_end TIMESTAMPTZ DEFAULT NULL
) RETURNS JSONB
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = public AS $$
  WITH totals AS (
    SELECT p.id, p.username, COALESCE(sum(e.points), 0)::INTEGER AS points
    FROM profiles p
    LEFT JOIN point_earnings e
      ON e.student_id = p.id
      AND e.teacher_id = p_teacher_id
      AND (p_start IS NULL OR e.created_at >= p_start)
      AND (p_end IS NULL OR e.created_at < p_end)
      AND NOT EXISTS (
        SELECT 1
        FROM task_completions c
        WHERE e.source_id = 'task:' || c.id AND c.revoked_at IS NOT NULL
      )
    WHERE p.teacher_id = p_teacher_id AND p.role = 'student'
    GROUP BY p.id, p.username
  ), ranked AS (
    SELECT t.*,
      CASE WHEN t.points > 0
        THEN row_number() OVER (ORDER BY t.points DESC, t.username, t.id)
        ELSE NULL
      END AS rank
    FROM totals t
  )
  SELECT jsonb_build_object(
    'periodStart', p_start,
    'periodEnd', p_end,
    'entries', COALESCE(
      (SELECT jsonb_agg(to_jsonb(r) ORDER BY r.points DESC, r.username, r.id) FROM ranked r),
      '[]'::JSONB
    )
  );
$$;

GRANT EXECUTE ON FUNCTION period_leaderboard(UUID, TIMESTAMPTZ, TIMESTAMPTZ) TO anon, authenticated;

COMMIT;
