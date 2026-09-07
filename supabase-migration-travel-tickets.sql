-- 任务奖励旅行券。先执行课堂、商城、旅行迁移，再执行本文件；可重复执行。
BEGIN;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS travel_tickets INTEGER NOT NULL DEFAULT 0 CHECK (travel_tickets BETWEEN 0 AND 100);
ALTER TABLE task_completions ADD COLUMN IF NOT EXISTS travel_tickets INTEGER NOT NULL DEFAULT 0 CHECK (travel_tickets >= 0);
ALTER TABLE task_completions ADD COLUMN IF NOT EXISTS revoked_at TIMESTAMPTZ;
ALTER TABLE task_completions ADD COLUMN IF NOT EXISTS revoked_by UUID REFERENCES profiles(id);
ALTER TABLE task_completions ADD COLUMN IF NOT EXISTS revoke_reason TEXT;
ALTER TABLE travel_wallets ADD COLUMN IF NOT EXISTS tickets INTEGER NOT NULL DEFAULT 0 CHECK (tickets >= 0);
-- 已出发的历史免费旅行继续有效，不补扣券。
ALTER TABLE pet_trips ADD COLUMN IF NOT EXISTS ticket_cost INTEGER NOT NULL DEFAULT 0 CHECK (ticket_cost IN (0,1));
ALTER TABLE pet_trips DROP CONSTRAINT IF EXISTS pet_trips_user_id_departure_day_key;

CREATE OR REPLACE FUNCTION award_task_points(
 p_actor_id UUID,p_student_id UUID,p_task_id UUID,p_request_id UUID
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE s profiles%ROWTYPE; t tasks%ROWTYPE; c task_completions%ROWTYPE;
BEGIN
 IF p_request_id IS NULL THEN RAISE EXCEPTION '缺少请求编号'; END IF;
 SELECT * INTO s FROM profiles WHERE id=p_student_id AND role='student' FOR UPDATE;
 IF NOT FOUND OR p_actor_id IS NULL OR s.teacher_id IS DISTINCT FROM p_actor_id
   OR NOT EXISTS(SELECT 1 FROM profiles WHERE id=p_actor_id AND role='teacher') THEN RAISE EXCEPTION '只能给本班学生发放奖励'; END IF;
 SELECT * INTO c FROM task_completions WHERE id=p_request_id;
 IF FOUND THEN
  IF c.student_id IS DISTINCT FROM s.id OR c.awarded_by IS DISTINCT FROM p_actor_id OR c.task_id IS DISTINCT FROM p_task_id THEN RAISE EXCEPTION '请求编号已用于其他操作'; END IF;
  RETURN jsonb_build_object('points',c.points,'travelTickets',c.travel_tickets,'balance',s.points);
 END IF;
 SELECT * INTO t FROM tasks WHERE id=p_task_id AND created_by=p_actor_id AND is_active=true FOR SHARE;
 IF NOT FOUND OR t.points IS NULL OR t.points<0 OR (t.points=0 AND t.travel_tickets=0) THEN RAISE EXCEPTION '任务已停用或未设置有效奖励'; END IF;
 INSERT INTO task_completions(id,task_id,student_id,awarded_by,points,travel_tickets)
 VALUES(p_request_id,t.id,s.id,p_actor_id,t.points,t.travel_tickets);
 UPDATE profiles SET points=COALESCE(points,0)+t.points WHERE id=s.id RETURNING * INTO s;
 IF t.points>0 THEN
  INSERT INTO point_earnings(source_id,student_id,teacher_id,points,reason) VALUES('task:'||p_request_id,s.id,p_actor_id,t.points,t.name);
 END IF;
 IF t.travel_tickets>0 THEN
  INSERT INTO travel_wallets(user_id,tickets) VALUES(s.id,t.travel_tickets)
  ON CONFLICT (user_id) DO UPDATE SET tickets=travel_wallets.tickets+EXCLUDED.tickets;
 END IF;
 RETURN jsonb_build_object('points',t.points,'travelTickets',t.travel_tickets,'balance',s.points);
END $$;

CREATE OR REPLACE FUNCTION revoke_task_award(p_actor_id UUID,p_completion_id UUID,p_reason TEXT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE c task_completions%ROWTYPE; s profiles%ROWTYPE; target_student UUID;
BEGIN
 SELECT student_id INTO target_student FROM task_completions WHERE id=p_completion_id;
 IF NOT FOUND THEN RAISE EXCEPTION '发放记录不存在'; END IF;
 SELECT * INTO s FROM profiles WHERE id=target_student AND role='student' FOR UPDATE;
 IF NOT FOUND OR p_actor_id IS NULL OR s.teacher_id IS DISTINCT FROM p_actor_id
  OR NOT EXISTS(SELECT 1 FROM profiles WHERE id=p_actor_id AND role='teacher') THEN RAISE EXCEPTION '只能撤销本班学生的奖励'; END IF;
 SELECT * INTO c FROM task_completions WHERE id=p_completion_id FOR UPDATE;
 IF NOT FOUND OR c.student_id IS DISTINCT FROM s.id OR c.awarded_by IS DISTINCT FROM p_actor_id THEN RAISE EXCEPTION '只能撤销自己发放的奖励'; END IF;
 IF c.revoked_at IS NOT NULL THEN RETURN jsonb_build_object('balance',s.points,'completion',to_jsonb(c),'alreadyRevoked',true); END IF;
 IF length(trim(COALESCE(p_reason,''))) NOT BETWEEN 1 AND 200 THEN RAISE EXCEPTION '请填写 1 至 200 字的撤销原因'; END IF;
 IF c.points<0 OR (c.points=0 AND c.travel_tickets=0) THEN RAISE EXCEPTION '该记录没有可撤销的奖励'; END IF;
 IF COALESCE(s.points,0)<c.points THEN RAISE EXCEPTION '学生积分余额不足，暂时无法撤销'; END IF;
 IF c.travel_tickets>0 THEN
  UPDATE travel_wallets SET tickets=tickets-c.travel_tickets WHERE user_id=s.id AND tickets>=c.travel_tickets;
  IF NOT FOUND THEN RAISE EXCEPTION '学生旅行券余额不足，暂时无法撤销该奖励'; END IF;
 END IF;
 UPDATE profiles SET points=points-c.points WHERE id=s.id RETURNING * INTO s;
 UPDATE task_completions SET revoked_at=now(),revoked_by=p_actor_id,revoke_reason=trim(p_reason) WHERE id=c.id RETURNING * INTO c;
 RETURN jsonb_build_object('balance',s.points,'completion',to_jsonb(c),'alreadyRevoked',false);
END $$;

REVOKE ALL ON FUNCTION award_task_points(UUID,UUID,UUID,UUID),revoke_task_award(UUID,UUID,TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION award_task_points(UUID,UUID,UUID,UUID),revoke_task_award(UUID,UUID,TEXT) TO anon,authenticated;
CREATE OR REPLACE FUNCTION travel_state(p_user_id UUID) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM profiles WHERE id=p_user_id AND role='student') THEN RAISE EXCEPTION '学生不存在'; END IF;
 RETURN jsonb_build_object(
  'serverNow',now(),
  'canDepart',COALESCE((SELECT tickets FROM travel_wallets WHERE user_id=p_user_id),0)>0 AND NOT EXISTS(SELECT 1 FROM pet_trips WHERE user_id=p_user_id AND claimed_at IS NULL),
  'tickets',COALESCE((SELECT tickets FROM travel_wallets WHERE user_id=p_user_id),0),
  'stamps',COALESCE((SELECT stamps FROM travel_wallets WHERE user_id=p_user_id),0),
  'destinations',(SELECT jsonb_agg(to_jsonb(d) ORDER BY sort_order) FROM travel_destinations d),
  'items',COALESCE((SELECT jsonb_agg(to_jsonb(i)||jsonb_build_object('destination_id',r.destination_id,'stamp_cost',r.stamp_cost,'owned',EXISTS(SELECT 1 FROM user_items u WHERE u.user_id=p_user_id AND u.item_id=i.id)) ORDER BY i.sort_order) FROM travel_rewards r JOIN shop_items i ON i.id=r.item_id),'[]'::jsonb),
  'active',(SELECT to_jsonb(t) FROM pet_trips t WHERE user_id=p_user_id AND claimed_at IS NULL),
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
 IF EXISTS(SELECT 1 FROM pet_trips WHERE user_id=p_user_id AND claimed_at IS NULL) THEN RAISE EXCEPTION '请先等待宠物归来并领取行李'; END IF;
 SELECT * INTO d FROM travel_destinations WHERE id=p_destination_id;
 IF NOT FOUND THEN RAISE EXCEPTION '目的地不存在'; END IF;
 UPDATE travel_wallets SET tickets=tickets-1 WHERE user_id=p_user_id AND tickets>=1;
 IF NOT FOUND THEN RAISE EXCEPTION '旅行券不足，完成老师指定的任务后再来出发吧'; END IF;
 INSERT INTO pet_trips(id,user_id,pet_id,pet_name,destination_id,returns_at,ticket_cost)
 VALUES(p_request_id,p_user_id,p_pet_id,pet_name_value,d.id,now()+make_interval(hours=>d.hours),1) RETURNING * INTO t;
 RETURN to_jsonb(t);
END $$;


COMMIT;
