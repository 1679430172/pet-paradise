-- 每只宠物独立旅行；在老师代旅行迁移之后执行，可重复执行。
BEGIN;
DROP INDEX IF EXISTS pet_trips_one_active;
CREATE UNIQUE INDEX IF NOT EXISTS pet_trips_one_active_per_pet ON pet_trips(pet_id) WHERE claimed_at IS NULL;
CREATE OR REPLACE FUNCTION travel_state(p_user_id UUID) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM profiles WHERE id=p_user_id AND role='student') THEN RAISE EXCEPTION '学生不存在'; END IF;
 RETURN jsonb_build_object(
  'serverNow',now(),
  'canDepart',COALESCE((SELECT tickets FROM travel_wallets WHERE user_id=p_user_id),0)>0 AND EXISTS(SELECT 1 FROM pets p WHERE p.owner_id=p_user_id AND NOT EXISTS(SELECT 1 FROM pet_trips t WHERE t.pet_id=p.id AND t.claimed_at IS NULL)),
  'tickets',COALESCE((SELECT tickets FROM travel_wallets WHERE user_id=p_user_id),0),
  'stamps',COALESCE((SELECT stamps FROM travel_wallets WHERE user_id=p_user_id),0),
  'destinations',(SELECT jsonb_agg(to_jsonb(d) ORDER BY sort_order) FROM travel_destinations d),
  'items',COALESCE((SELECT jsonb_agg(to_jsonb(i)||jsonb_build_object('destination_id',r.destination_id,'stamp_cost',r.stamp_cost,'owned',EXISTS(SELECT 1 FROM user_items u WHERE u.user_id=p_user_id AND u.item_id=i.id)) ORDER BY i.sort_order) FROM travel_rewards r JOIN shop_items i ON i.id=r.item_id),'[]'::jsonb),
  'active',(SELECT to_jsonb(t) FROM pet_trips t WHERE user_id=p_user_id AND claimed_at IS NULL ORDER BY started_at,id LIMIT 1),
  'activeTrips',COALESCE((SELECT jsonb_agg(to_jsonb(t) ORDER BY started_at,id) FROM pet_trips t WHERE user_id=p_user_id AND claimed_at IS NULL),'[]'::jsonb),
  'history',COALESCE((SELECT jsonb_agg(to_jsonb(h) ORDER BY started_at DESC) FROM (SELECT * FROM pet_trips WHERE user_id=p_user_id AND claimed_at IS NOT NULL ORDER BY started_at DESC LIMIT 20) h),'[]'::jsonb),
  'postcards',COALESCE((SELECT jsonb_agg(c) FROM (SELECT DISTINCT destination_id,reward->>'story' AS story FROM pet_trips WHERE user_id=p_user_id AND claimed_at IS NOT NULL) c),'[]'::jsonb)
 );
END $$;

CREATE OR REPLACE FUNCTION start_pet_trip(p_user_id UUID,p_pet_id UUID,p_destination_id TEXT,p_request_id UUID) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE d travel_destinations%ROWTYPE; t pet_trips%ROWTYPE; pet_name_value TEXT;
BEGIN
 PERFORM 1 FROM profiles WHERE id=p_user_id AND role='student' FOR UPDATE;
 IF NOT FOUND OR p_request_id IS NULL THEN RAISE EXCEPTION '无效的出发请求'; END IF;
 SELECT * INTO t FROM pet_trips WHERE id=p_request_id;
 IF FOUND THEN
  IF t.user_id IS DISTINCT FROM p_user_id OR t.pet_id IS DISTINCT FROM p_pet_id OR t.destination_id IS DISTINCT FROM p_destination_id THEN RAISE EXCEPTION '请求编号已被使用'; END IF;
  RETURN to_jsonb(t);
 END IF;
 SELECT name INTO pet_name_value FROM pets WHERE id=p_pet_id AND owner_id=p_user_id FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION '请选择自己的宠物'; END IF;
 IF EXISTS(SELECT 1 FROM pet_trips WHERE pet_id=p_pet_id AND claimed_at IS NULL) THEN RAISE EXCEPTION '请先等待宠物归来并领取行李'; END IF;
 SELECT * INTO d FROM travel_destinations WHERE id=p_destination_id;
 IF NOT FOUND THEN RAISE EXCEPTION '目的地不存在'; END IF;
 UPDATE travel_wallets SET tickets=tickets-1 WHERE user_id=p_user_id AND tickets>=1;
 IF NOT FOUND THEN RAISE EXCEPTION '旅行券不足，完成老师指定的任务后再来出发吧'; END IF;
 INSERT INTO pet_trips(id,user_id,pet_id,pet_name,destination_id,returns_at,ticket_cost)
 VALUES(p_request_id,p_user_id,p_pet_id,pet_name_value,d.id,now()+make_interval(hours=>d.hours),1) RETURNING * INTO t;
 RETURN to_jsonb(t);
END $$;


COMMIT;
