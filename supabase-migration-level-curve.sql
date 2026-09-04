-- 将已部署项目的宠物等级曲线更新为 Lv.20 累计 3050 XP。
-- 执行后会同步重算现有宠物等级；宠物已获得的 XP 不变。

CREATE OR REPLACE FUNCTION feed_pet(
  p_actor_id UUID, p_student_id UUID, p_pet_id UUID, p_action TEXT, p_request_id UUID
) RETURNS JSONB LANGUAGE plpgsql SECURITY INVOKER SET search_path = public AS $$
DECLARE
  s profiles%ROWTYPE;
  p pets%ROWTYPE;
  e feeding_events%ROWTYPE;
  price INTEGER;
  gain INTEGER;
  food_xp INTEGER;
  prices JSONB;
  old_level INTEGER;
  result JSONB;
  thresholds INTEGER[] := ARRAY[0,20,50,90,140,200,275,365,470,590,730,890,1070,1270,1495,1745,2025,2335,2675,3050];
BEGIN
  IF p_request_id IS NULL OR p_actor_id IS NULL OR p_student_id IS NULL OR p_pet_id IS NULL OR p_action IS NULL OR p_action NOT IN ('basic','nice','luxury') THEN
    RAISE EXCEPTION '无效的喂食请求';
  END IF;
  SELECT * INTO s FROM profiles WHERE id = p_student_id AND role = 'student' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION '学生不存在'; END IF;
  IF NOT (p_actor_id = s.id OR EXISTS (
    SELECT 1 FROM profiles a WHERE a.id = p_actor_id AND a.role = 'teacher' AND a.id = s.teacher_id
  )) THEN RAISE EXCEPTION '只能照顾本人或本班学生的宠物'; END IF;

  SELECT * INTO e FROM feeding_events WHERE request_id = p_request_id;
  IF FOUND THEN
    IF e.actor_id IS DISTINCT FROM p_actor_id OR e.student_id IS DISTINCT FROM p_student_id OR e.pet_id IS DISTINCT FROM p_pet_id OR e.action IS DISTINCT FROM p_action THEN
      RAISE EXCEPTION '请求编号已用于其他操作';
    END IF;
    RETURN e.result;
  END IF;
  SELECT * INTO p FROM pets WHERE id = p_pet_id AND owner_id = s.id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION '宠物不存在或不属于该学生'; END IF;
  SELECT value INTO prices FROM settings WHERE key = 'action_costs';
  price := COALESCE((prices ->> p_action)::INTEGER, CASE p_action WHEN 'basic' THEN 5 WHEN 'nice' THEN 10 ELSE 20 END);
  IF price < 0 THEN RAISE EXCEPTION '喂食价格配置无效'; END IF;
  IF COALESCE(s.points, 0) < price THEN RAISE EXCEPTION '积分不足，需要 % 积分', price; END IF;
  gain := CASE p_action WHEN 'basic' THEN 25 WHEN 'nice' THEN 55 ELSE 100 END;
  food_xp := CASE p_action WHEN 'basic' THEN 8 WHEN 'nice' THEN 18 ELSE 40 END;
  old_level := COALESCE(p.level, 1);
  p.hunger := LEAST(100, GREATEST(0, COALESCE(p.hunger,0) - floor(
    floor(GREATEST(0, extract(epoch FROM (now() - COALESCE(p.last_fed_at,p.created_at,now())))) / 3600) * 1.5
  )::INTEGER) + gain);
  p.xp := COALESCE(p.xp, 0) + food_xp;
  SELECT count(*)::INTEGER INTO p.level FROM unnest(thresholds) AS threshold WHERE threshold <= p.xp;
  UPDATE profiles SET points = COALESCE(points,0) - price WHERE id = s.id RETURNING * INTO s;
  UPDATE pets SET hunger = p.hunger, xp = p.xp, level = p.level, last_fed_at = now()
    WHERE id = p.id RETURNING * INTO p;
  result := jsonb_build_object('points',s.points,'pet',to_jsonb(p),'cost',price,'leveledUp',p.level > old_level);
  INSERT INTO feeding_events(request_id,actor_id,student_id,pet_id,action,result)
    VALUES(p_request_id,p_actor_id,s.id,p.id,p_action,result);
  RETURN result;
END $$;

WITH level_curve AS (
  SELECT ARRAY[0,20,50,90,140,200,275,365,470,590,730,890,1070,1270,1495,1745,2025,2335,2675,3050]::INTEGER[] AS thresholds
)
UPDATE pets p
SET level = (
  SELECT count(*)::INTEGER
  FROM level_curve, unnest(level_curve.thresholds) AS threshold
  WHERE threshold <= COALESCE(p.xp, 0)
);
