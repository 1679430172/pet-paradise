-- 周榜不使用并列名次：积分相同时按学生名称、学生 ID 稳定排序。
BEGIN;

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
    SELECT t.*,CASE WHEN t.points > 0 THEN row_number() OVER (ORDER BY t.points DESC,t.username,t.id) ELSE NULL END AS rank,
      COALESCE(pet.level,0) AS pet_level,COALESCE(pet.name,'未领养') AS pet_name
    FROM totals t LEFT JOIN LATERAL (
      SELECT name,level FROM pets WHERE owner_id = t.id ORDER BY level DESC,created_at,id LIMIT 1
    ) pet ON true
  ) SELECT jsonb_build_object('weekStart',w.start_at,'weekEnd',w.start_at + interval '7 days',
    'entries',COALESCE((SELECT jsonb_agg(to_jsonb(r) ORDER BY r.points DESC,r.username,r.id) FROM ranked r),'[]'::JSONB))
  FROM period w;
$$;

GRANT EXECUTE ON FUNCTION weekly_leaderboard(UUID) TO anon, authenticated;

COMMIT;
