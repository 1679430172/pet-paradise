-- After postcard-unlocks and per-pet-travel. Safe to run repeatedly.
BEGIN;
ALTER TABLE pet_trips ADD COLUMN IF NOT EXISTS pet_snapshot JSONB;

CREATE OR REPLACE FUNCTION capture_trip_pet_snapshot() RETURNS TRIGGER
LANGUAGE plpgsql SET search_path=public AS $$
DECLARE p pets%ROWTYPE; stage_name TEXT;
BEGIN
 IF TG_OP='UPDATE' THEN
  -- Never replace historical identity during claim, rename, evolution or pet deletion.
  NEW.pet_snapshot := OLD.pet_snapshot;
  RETURN NEW;
 END IF;
 SELECT * INTO p FROM pets WHERE id=NEW.pet_id AND owner_id=NEW.user_id FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION '请选择自己的宠物'; END IF;
 stage_name := CASE WHEN p.level>=20 THEN 'final' WHEN p.level>=14 THEN 'adult'
                    WHEN p.level>=9 THEN 'teen' WHEN p.level>=4 THEN 'baby' ELSE 'egg' END;
 NEW.pet_snapshot := jsonb_build_object('id',p.id,'name',p.name,'species',p.species,
   'level',p.level,'stage',stage_name,'appearance',p.appearance);
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS pet_trip_snapshot ON pet_trips;
CREATE TRIGGER pet_trip_snapshot BEFORE INSERT OR UPDATE ON pet_trips
 FOR EACH ROW EXECUTE FUNCTION capture_trip_pet_snapshot();
REVOKE ALL ON FUNCTION capture_trip_pet_snapshot() FROM PUBLIC;

-- Earlier trips did not record species/stage at departure. Do not invent them
-- from the current pet. Keep the recorded name/ID and mark them historical.
CREATE OR REPLACE FUNCTION travel_state(p_user_id UUID) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
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
  'postcards',COALESCE((SELECT jsonb_agg(c ORDER BY c.collected_at DESC,c.id) FROM (
    SELECT t.id::TEXT AS id,t.destination_id,t.reward->>'story' AS story,t.pet_snapshot,
      COALESCE(t.pet_snapshot->>'id',t.pet_id::TEXT) AS pet_id,
      COALESCE(t.pet_snapshot->>'name',t.pet_name) AS pet_name,
      CASE WHEN t.pet_snapshot IS NULL THEN 'legacy' ELSE 'trip' END AS source,
      t.claimed_at AS collected_at
    FROM pet_trips t WHERE t.user_id=p_user_id AND t.claimed_at IS NOT NULL AND t.reward->>'story' IS NOT NULL
    UNION ALL
    SELECT 'gift:'||u.destination_id||':'||md5(u.story),u.destination_id,u.story,NULL::JSONB,
      NULL::TEXT,NULL::TEXT,'gift',u.created_at
    FROM travel_postcard_unlocks u WHERE u.user_id=p_user_id
  ) c),'[]'::jsonb)
 );
END $$;
COMMIT;
