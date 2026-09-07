-- 老师代旅行；先执行旅行券和统一收支迁移。可重复执行。
BEGIN;
ALTER TABLE pet_trips ADD COLUMN IF NOT EXISTS started_by UUID;
ALTER TABLE pet_trips ADD COLUMN IF NOT EXISTS claimed_by UUID;

CREATE OR REPLACE FUNCTION teacher_travel_state(p_actor_id UUID,p_student_id UUID) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM profiles WHERE id=p_actor_id AND role='teacher')
 OR NOT EXISTS(SELECT 1 FROM profiles WHERE id=p_student_id AND role='student' AND teacher_id=p_actor_id) THEN RAISE EXCEPTION '只能操作本班学生的旅行'; END IF;
 RETURN travel_state(p_student_id);
END $$;

CREATE OR REPLACE FUNCTION teacher_start_pet_trip(p_actor_id UUID,p_student_id UUID,p_pet_id UUID,p_destination_id TEXT,p_request_id UUID) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE result JSONB;
BEGIN
 PERFORM 1 FROM profiles WHERE id=p_student_id AND role='student' AND teacher_id=p_actor_id FOR UPDATE;
 IF NOT FOUND OR NOT EXISTS(SELECT 1 FROM profiles WHERE id=p_actor_id AND role='teacher') THEN RAISE EXCEPTION '只能操作本班学生的旅行'; END IF;
 IF EXISTS(SELECT 1 FROM pet_trips WHERE id=p_request_id AND COALESCE(started_by,user_id) IS DISTINCT FROM p_actor_id) THEN RAISE EXCEPTION '请求编号已用于其他操作'; END IF;
 result:=start_pet_trip(p_student_id,p_pet_id,p_destination_id,p_request_id);
 UPDATE pet_trips SET started_by=p_actor_id WHERE id=p_request_id;
 RETURN result||jsonb_build_object('started_by',p_actor_id);
END $$;

CREATE OR REPLACE FUNCTION teacher_claim_pet_trip(p_actor_id UUID,p_student_id UUID,p_trip_id UUID) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE result JSONB; was_claimed BOOLEAN;
BEGIN
 PERFORM 1 FROM profiles WHERE id=p_student_id AND role='student' AND teacher_id=p_actor_id FOR UPDATE;
 IF NOT FOUND OR NOT EXISTS(SELECT 1 FROM profiles WHERE id=p_actor_id AND role='teacher') THEN RAISE EXCEPTION '只能操作本班学生的旅行'; END IF;
 SELECT claimed_at IS NOT NULL INTO was_claimed FROM pet_trips WHERE id=p_trip_id AND user_id=p_student_id;
 result:=claim_pet_trip(p_student_id,p_trip_id);
 IF NOT was_claimed THEN UPDATE pet_trips SET claimed_by=p_actor_id WHERE id=p_trip_id; END IF;
 RETURN result;
END $$;

CREATE OR REPLACE FUNCTION teacher_travel_overview(p_actor_id UUID) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM profiles WHERE id=p_actor_id AND role='teacher') THEN RAISE EXCEPTION '仅老师可查看班级旅行'; END IF;
 RETURN jsonb_build_object('serverNow',now(),'entries',COALESCE((SELECT jsonb_agg(jsonb_build_object('student_id',t.user_id,'pet_id',t.pet_id,'pet_name',t.pet_name,'returns_at',t.returns_at)) FROM pet_trips t JOIN profiles p ON p.id=t.user_id WHERE p.teacher_id=p_actor_id AND t.claimed_at IS NULL),'[]'::jsonb));
END $$;
REVOKE ALL ON FUNCTION teacher_travel_state(UUID,UUID),teacher_start_pet_trip(UUID,UUID,UUID,TEXT,UUID),teacher_claim_pet_trip(UUID,UUID,UUID),teacher_travel_overview(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION teacher_travel_state(UUID,UUID),teacher_start_pet_trip(UUID,UUID,UUID,TEXT,UUID),teacher_claim_pet_trip(UUID,UUID,UUID),teacher_travel_overview(UUID) TO anon,authenticated;
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
 SELECT 'trip:'||t.id,t.user_id,t.started_at,'travel',t.pet_name||' · '||d.name,0,-t.ticket_cost,COALESCE(t.started_by,t.user_id),NULL::integer
 FROM pet_trips t JOIN travel_destinations d ON d.id=t.destination_id WHERE t.ticket_cost>0
 UNION ALL
 SELECT 'revoke:'||c.id,c.student_id,c.revoked_at,'revoke',COALESCE(t.name,'任务奖励')||' · '||COALESCE(c.revoke_reason,'撤销奖励'),-c.points,-c.travel_tickets,c.revoked_by,NULL::integer
 FROM task_completions c LEFT JOIN tasks t ON t.id=c.task_id WHERE c.revoked_at IS NOT NULL AND (c.points>0 OR c.travel_tickets>0);

COMMIT;
