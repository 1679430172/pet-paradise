-- 独立的明信片赠送记录，不伪造旅行或发放其他奖励。
-- 在多宠物旅行迁移之后执行；可重复执行。
BEGIN;
CREATE TABLE IF NOT EXISTS travel_postcard_unlocks (
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  destination_id TEXT NOT NULL REFERENCES travel_destinations(id),
  story TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY(user_id,destination_id,story)
);
ALTER TABLE travel_postcard_unlocks ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON travel_postcard_unlocks FROM anon,authenticated;
DO $$
DECLARE
  definition TEXT := pg_get_functiondef('public.travel_state(uuid)'::regprocedure);
  original TEXT := 'SELECT DISTINCT destination_id,reward->>''story'' AS story FROM pet_trips WHERE user_id=p_user_id AND claimed_at IS NOT NULL';
BEGIN
  IF strpos(definition,'travel_postcard_unlocks')=0 THEN
    IF strpos(definition,original)=0 THEN
      RAISE EXCEPTION 'travel_state has changed; review postcard query before migration';
    END IF;
    EXECUTE replace(definition,original,original || ' UNION SELECT destination_id,story FROM travel_postcard_unlocks WHERE user_id=p_user_id');
  END IF;
END $$;
COMMIT;
