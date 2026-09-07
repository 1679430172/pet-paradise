-- 统一积分/旅行券收支记录。先执行课堂、商城和旅行券迁移；可重复执行。
BEGIN;
CREATE OR REPLACE VIEW student_resource_ledger AS
 SELECT 'award:'||c.id AS id,c.student_id,c.created_at,'award'::text AS kind,COALESCE(t.name,'任务奖励') AS description,
 c.points AS points_delta,c.travel_tickets AS tickets_delta,c.awarded_by AS actor_id,NULL::integer AS balance_after
 FROM task_completions c LEFT JOIN tasks t ON t.id=c.task_id WHERE c.points<>0 OR c.travel_tickets<>0
 UNION ALL
 SELECT 'earning:'||e.source_id,e.student_id,e.created_at,'earning',e.reason,e.points,0,e.student_id,NULL::integer
 FROM point_earnings e WHERE NOT EXISTS(SELECT 1 FROM task_completions c WHERE e.source_id='task:'||c.id)
 UNION ALL
 SELECT 'feed:'||e.request_id,e.student_id,e.created_at,'feeding',COALESCE(e.result->'pet'->>'name','宠物')||' · '||CASE e.action WHEN 'basic' THEN '普通粮' WHEN 'nice' THEN '营养粮' WHEN 'luxury' THEN '豪华粮' ELSE e.action END,
 -(e.result->>'cost')::integer,0,e.actor_id,(e.result->>'points')::integer FROM feeding_events e WHERE (e.result->>'cost')::integer>0
 UNION ALL
 SELECT 'shop:'||o.id,o.buyer_id,o.created_at,'shop',COALESCE(i.name,'装扮商品'),-o.price,0,o.actor_id,o.balance_after
 FROM shop_orders o LEFT JOIN shop_items i ON i.id=o.item_id WHERE o.price>0
 UNION ALL
 SELECT 'trip:'||t.id,t.user_id,t.started_at,'travel',t.pet_name||' · '||d.name,0,-t.ticket_cost,t.user_id,NULL::integer
 FROM pet_trips t JOIN travel_destinations d ON d.id=t.destination_id WHERE t.ticket_cost>0
 UNION ALL
 SELECT 'revoke:'||c.id,c.student_id,c.revoked_at,'revoke',COALESCE(t.name,'任务奖励')||' · '||COALESCE(c.revoke_reason,'撤销奖励'),-c.points,-c.travel_tickets,c.revoked_by,NULL::integer
 FROM task_completions c LEFT JOIN tasks t ON t.id=c.task_id WHERE c.revoked_at IS NOT NULL AND (c.points>0 OR c.travel_tickets>0);
REVOKE ALL ON student_resource_ledger FROM PUBLIC,anon,authenticated;
CREATE OR REPLACE FUNCTION teacher_student_ledger(p_actor_id UUID,p_student_id UUID,p_page INTEGER DEFAULT 1)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE total INTEGER; page_number INTEGER; current_points INTEGER;
BEGIN
 SELECT points INTO current_points FROM profiles WHERE id=p_student_id AND role='student' AND teacher_id=p_actor_id;
 IF NOT FOUND OR NOT EXISTS(SELECT 1 FROM profiles WHERE id=p_actor_id AND role='teacher') THEN RAISE EXCEPTION '只能查看本班学生的收支记录'; END IF;
 SELECT count(*) INTO total FROM student_resource_ledger WHERE student_id=p_student_id;
 page_number:=LEAST(GREATEST(COALESCE(p_page,1),1),GREATEST(1,(total+9)/10));
 RETURN jsonb_build_object('points',COALESCE(current_points,0),'tickets',COALESCE((SELECT tickets FROM travel_wallets WHERE user_id=p_student_id),0),
 'total',total,'page',page_number,'pageSize',10,'entries',COALESCE((SELECT jsonb_agg(to_jsonb(r) ORDER BY r.created_at DESC,r.id DESC) FROM (
  SELECT e.id,e.created_at,e.kind,e.description,e.points_delta,e.tickets_delta,e.balance_after,
   CASE WHEN e.actor_id=p_student_id THEN '学生本人' ELSE COALESCE(a.username,'历史操作人') END AS actor_name,
   CASE WHEN e.actor_id=p_student_id THEN 'student' ELSE COALESCE(a.role,'unknown') END AS actor_role
  FROM student_resource_ledger e LEFT JOIN profiles a ON a.id=e.actor_id WHERE e.student_id=p_student_id
  ORDER BY e.created_at DESC,e.id DESC LIMIT 10 OFFSET (page_number-1)*10
 ) r),'[]'::jsonb));
END $$;
REVOKE ALL ON FUNCTION teacher_student_ledger(UUID,UUID,INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION teacher_student_ledger(UUID,UUID,INTEGER) TO anon,authenticated;
COMMIT;
