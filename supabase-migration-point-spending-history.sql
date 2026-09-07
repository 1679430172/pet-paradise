-- 积分使用记录。先部署课堂、商城和奖励撤销迁移；可重复执行。
BEGIN;
CREATE INDEX IF NOT EXISTS feeding_events_student_created_idx ON feeding_events(student_id,created_at DESC);
CREATE OR REPLACE VIEW student_point_spending AS
 SELECT 'feed:'||e.request_id AS id,e.student_id,e.created_at,'feeding'::text AS kind,
  COALESCE(e.result->'pet'->>'name','宠物')||' · '||CASE e.action WHEN 'basic' THEN '普通粮' WHEN 'nice' THEN '营养粮' WHEN 'luxury' THEN '豪华粮' ELSE e.action END AS description,
  (e.result->>'cost')::integer AS cost,(e.result->>'points')::integer AS balance_after,
  e.actor_id
 FROM feeding_events e WHERE (e.result->>'cost')::integer>0
 UNION ALL
 SELECT 'shop:'||o.id,o.buyer_id,o.created_at,'shop',COALESCE(i.name,'装扮商品'),o.price,o.balance_after,o.actor_id
 FROM shop_orders o LEFT JOIN shop_items i ON i.id=o.item_id WHERE o.price>0
 UNION ALL
 SELECT 'revoke:'||c.id,c.student_id,c.revoked_at,'revoke',COALESCE(t.name,'任务奖励')||' · '||COALESCE(c.revoke_reason,'撤销奖励'),c.points,NULL::integer,c.revoked_by
 FROM task_completions c LEFT JOIN tasks t ON t.id=c.task_id WHERE c.revoked_at IS NOT NULL AND c.points>0;
REVOKE ALL ON student_point_spending FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION teacher_point_spending(p_actor_id UUID,p_student_id UUID,p_page INTEGER DEFAULT 1)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE total INTEGER; page_number INTEGER; current_points INTEGER;
BEGIN
 SELECT points INTO current_points FROM profiles WHERE id=p_student_id AND role='student' AND teacher_id=p_actor_id;
 IF NOT FOUND OR NOT EXISTS(SELECT 1 FROM profiles WHERE id=p_actor_id AND role='teacher') THEN RAISE EXCEPTION '只能查看本班学生的积分使用记录'; END IF;
 SELECT count(*) INTO total FROM student_point_spending WHERE student_id=p_student_id;
 page_number:=LEAST(GREATEST(COALESCE(p_page,1),1),GREATEST(1,(total+9)/10));
 RETURN jsonb_build_object('points',COALESCE(current_points,0),'total',total,'page',page_number,'pageSize',10,
  'entries',COALESCE((SELECT jsonb_agg(to_jsonb(r) ORDER BY r.created_at DESC,r.id DESC) FROM (
    SELECT e.id,e.created_at,e.kind,e.description,e.cost,e.balance_after,
      CASE WHEN e.actor_id=p_student_id THEN '学生本人' ELSE COALESCE(a.username,'历史操作人') END AS actor_name,
      CASE WHEN e.actor_id=p_student_id THEN 'student' ELSE COALESCE(a.role,'unknown') END AS actor_role
    FROM student_point_spending e LEFT JOIN profiles a ON a.id=e.actor_id WHERE e.student_id=p_student_id
    ORDER BY e.created_at DESC,e.id DESC LIMIT 10 OFFSET (page_number-1)*10
  ) r),'[]'::jsonb));
END $$;
REVOKE ALL ON FUNCTION teacher_point_spending(UUID,UUID,INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION teacher_point_spending(UUID,UUID,INTEGER) TO anon,authenticated;
COMMIT;
