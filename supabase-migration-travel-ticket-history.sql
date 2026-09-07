-- 先执行旅行券迁移，再执行本文件；可重复执行。
BEGIN;
CREATE INDEX IF NOT EXISTS pet_trips_user_started_idx ON pet_trips(user_id,started_at DESC,id DESC);
CREATE OR REPLACE FUNCTION teacher_travel_ticket_usage(p_actor_id UUID,p_student_id UUID,p_page INTEGER DEFAULT 1)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE total INTEGER; page_number INTEGER;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM profiles WHERE id=p_actor_id AND role='teacher')
  OR NOT EXISTS(SELECT 1 FROM profiles WHERE id=p_student_id AND role='student' AND teacher_id=p_actor_id)
 THEN RAISE EXCEPTION '只能查看本班学生的旅行券使用记录'; END IF;
 SELECT count(*) INTO total FROM pet_trips WHERE user_id=p_student_id AND ticket_cost>0;
 page_number := LEAST(GREATEST(COALESCE(p_page,1),1),GREATEST(1,(total+9)/10));
 RETURN jsonb_build_object(
  'tickets',COALESCE((SELECT tickets FROM travel_wallets WHERE user_id=p_student_id),0),
  'total',total,'page',page_number,'pageSize',10,
  'entries',COALESCE((SELECT jsonb_agg(to_jsonb(r) ORDER BY r.started_at DESC,r.id DESC) FROM (
    SELECT t.id,t.pet_name,d.name AS destination_name,t.ticket_cost,t.started_at,t.returns_at,
      CASE WHEN t.claimed_at IS NOT NULL THEN 'claimed' WHEN t.returns_at<=now() THEN 'returned' ELSE 'travelling' END AS status
    FROM pet_trips t JOIN travel_destinations d ON d.id=t.destination_id
    WHERE t.user_id=p_student_id AND t.ticket_cost>0
    ORDER BY t.started_at DESC,t.id DESC LIMIT 10 OFFSET (page_number-1)*10
  ) r),'[]'::jsonb)
 );
END $$;
REVOKE ALL ON FUNCTION teacher_travel_ticket_usage(UUID,UUID,INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION teacher_travel_ticket_usage(UUID,UUID,INTEGER) TO anon,authenticated;
COMMIT;
