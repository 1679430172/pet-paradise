-- 宠物旅行。先执行商城迁移，再执行本文件；可重复执行。
-- 沿用项目现有自定义账号 RPC 身份模型（调用方传学生 ID）。
BEGIN;
ALTER TABLE shop_items ADD COLUMN IF NOT EXISTS acquisition TEXT NOT NULL DEFAULT 'shop'
  CHECK (acquisition IN ('shop','travel'));
ALTER TABLE user_items ALTER COLUMN order_id DROP NOT NULL;

CREATE TABLE IF NOT EXISTS travel_destinations (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  icon TEXT NOT NULL,
  description TEXT NOT NULL,
  hours INTEGER NOT NULL CHECK (hours > 0),
  stories TEXT[] NOT NULL CHECK (cardinality(stories) > 0),
  sort_order INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS travel_rewards (
  item_id UUID PRIMARY KEY REFERENCES shop_items(id),
  destination_id TEXT NOT NULL REFERENCES travel_destinations(id),
  stamp_cost INTEGER NOT NULL DEFAULT 8 CHECK (stamp_cost > 0)
);
CREATE TABLE IF NOT EXISTS travel_wallets (
  user_id UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
  stamps INTEGER NOT NULL DEFAULT 0 CHECK (stamps >= 0)
);
CREATE TABLE IF NOT EXISTS pet_trips (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  pet_id UUID REFERENCES pets(id) ON DELETE SET NULL,
  pet_name TEXT NOT NULL,
  destination_id TEXT NOT NULL REFERENCES travel_destinations(id),
  started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  departure_day DATE NOT NULL DEFAULT (now() AT TIME ZONE 'Asia/Shanghai')::date,
  returns_at TIMESTAMPTZ NOT NULL,
  claimed_at TIMESTAMPTZ,
  reward JSONB,
  UNIQUE(user_id, departure_day),
  CHECK (returns_at > started_at),
  CHECK ((claimed_at IS NULL) = (reward IS NULL))
);
CREATE UNIQUE INDEX IF NOT EXISTS pet_trips_one_active ON pet_trips(user_id) WHERE claimed_at IS NULL;

INSERT INTO travel_destinations VALUES
 ('forest','森林营地','🌲','沿着林间小径，寻找藏在树叶里的惊喜。',4,ARRAY['今天遇见了一只松鼠，它送给我一片心形的叶子。','在溪水边歇了歇脚，把森林清晨的声音带回来给你。','搭好小帐篷后，看见萤火虫在树间点起了灯。'],1),
 ('coast','贝壳海湾','🐚','听海浪说话，把海边的温柔装进行李。',8,ARRAY['今天在海边捡到一枚漂亮的贝壳，想带回来送给你。','小螃蟹教我在沙滩上画画，我画的是你！','等到了橘子色的日落，把这一刻寄给最想念的你。'],2),
 ('stars','星光山谷','🌌','走向静谧山谷，收藏一整晚的星光。',12,ARRAY['抬头数星星的时候，每一颗都像你给我的鼓励。','在山顶看见一颗流星，偷偷许了和你有关的愿望。','裹着小毯子等天亮，把第一缕晨光装进了背包。'],3)
ON CONFLICT (id) DO UPDATE SET name=EXCLUDED.name,icon=EXCLUDED.icon,description=EXCLUDED.description,hours=EXCLUDED.hours,stories=EXCLUDED.stories;

INSERT INTO shop_items(slug,name,description,category,style_key,price,icon,sort_order,acquisition) VALUES
 ('travel-forest-frame','林间邮票','森林营地专属边框','frame','travel-forest',0,'🌿',210,'travel'),
 ('travel-forest-bg','萤火森林','森林营地专属背景','background','travel-forest',0,'🌲',211,'travel'),
 ('travel-coast-frame','贝壳来信','贝壳海湾专属边框','frame','travel-coast',0,'🐚',220,'travel'),
 ('travel-coast-bg','晴日海岸','贝壳海湾专属背景','background','travel-coast',0,'🏖️',221,'travel'),
 ('travel-stars-frame','星轨信笺','星光山谷专属边框','frame','travel-stars',0,'✨',230,'travel'),
 ('travel-stars-bg','山谷星河','星光山谷专属背景','background','travel-stars',0,'🌌',231,'travel')
ON CONFLICT (slug) DO UPDATE SET name=EXCLUDED.name,description=EXCLUDED.description,acquisition=EXCLUDED.acquisition;
INSERT INTO travel_rewards(item_id,destination_id)
 SELECT id,split_part(slug,'-',2) FROM shop_items WHERE slug IN
 ('travel-forest-frame','travel-forest-bg','travel-coast-frame','travel-coast-bg','travel-stars-frame','travel-stars-bg')
ON CONFLICT (item_id) DO NOTHING;

-- 同时覆盖学生购买和老师代购；事务失败会回滚积分扣除。
CREATE OR REPLACE FUNCTION reject_travel_purchase() RETURNS TRIGGER
LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
 IF EXISTS(SELECT 1 FROM shop_items WHERE id=NEW.item_id AND acquisition='travel') THEN
   RAISE EXCEPTION '旅行专属装扮，请通过旅行或印章兑换获得';
 END IF;
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS reject_travel_purchase ON shop_orders;
CREATE TRIGGER reject_travel_purchase BEFORE INSERT OR UPDATE ON shop_orders
 FOR EACH ROW EXECUTE FUNCTION reject_travel_purchase();

CREATE OR REPLACE FUNCTION travel_state(p_user_id UUID) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM profiles WHERE id=p_user_id AND role='student') THEN RAISE EXCEPTION '学生不存在'; END IF;
 RETURN jsonb_build_object(
  'serverNow',now(),
  'nextReset',(((now() AT TIME ZONE 'Asia/Shanghai')::date+1)::timestamp AT TIME ZONE 'Asia/Shanghai'),
  'canDepart',NOT EXISTS(SELECT 1 FROM pet_trips WHERE user_id=p_user_id AND (claimed_at IS NULL OR departure_day=(now() AT TIME ZONE 'Asia/Shanghai')::date)),
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
 IF EXISTS(SELECT 1 FROM pet_trips WHERE user_id=p_user_id AND departure_day=(now() AT TIME ZONE 'Asia/Shanghai')::date) THEN RAISE EXCEPTION '今天已经出发过啦，明天再来吧'; END IF;
 SELECT * INTO d FROM travel_destinations WHERE id=p_destination_id;
 IF NOT FOUND THEN RAISE EXCEPTION '目的地不存在'; END IF;
 INSERT INTO pet_trips(id,user_id,pet_id,pet_name,destination_id,returns_at)
 VALUES(p_request_id,p_user_id,p_pet_id,pet_name_value,d.id,now()+make_interval(hours=>d.hours)) RETURNING * INTO t;
 RETURN to_jsonb(t);
END $$;

CREATE OR REPLACE FUNCTION claim_pet_trip(p_user_id UUID,p_trip_id UUID) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE t pet_trips%ROWTYPE; d travel_destinations%ROWTYPE; item shop_items%ROWTYPE;
 story TEXT; bonus INTEGER := 1; duplicate BOOLEAN := false; result JSONB;
BEGIN
 PERFORM 1 FROM profiles WHERE id=p_user_id AND role='student' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION '学生不存在'; END IF;
 SELECT * INTO t FROM pet_trips WHERE id=p_trip_id AND user_id=p_user_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION '旅行记录不存在'; END IF;
 IF t.claimed_at IS NOT NULL THEN RETURN t.reward; END IF;
 IF now()<t.returns_at THEN RAISE EXCEPTION '宠物还在路上，请耐心等待'; END IF;
 SELECT * INTO d FROM travel_destinations WHERE id=t.destination_id;
 story := d.stories[1+floor(random()*cardinality(d.stories))::integer];
 -- 每次保底明信片及 1 印章；1% 概率获得当地装扮，两款均分。
 IF random()<0.01 THEN
  SELECT i.* INTO item FROM travel_rewards r JOIN shop_items i ON i.id=r.item_id WHERE r.destination_id=d.id ORDER BY random() LIMIT 1;
  IF FOUND THEN
   duplicate := EXISTS(SELECT 1 FROM user_items WHERE user_id=p_user_id AND item_id=item.id);
   IF duplicate THEN bonus := bonus+2;
   ELSE INSERT INTO user_items(user_id,item_id) VALUES(p_user_id,item.id); END IF;
  END IF;
 END IF;
 INSERT INTO travel_wallets(user_id,stamps) VALUES(p_user_id,bonus)
 ON CONFLICT (user_id) DO UPDATE SET stamps=travel_wallets.stamps+EXCLUDED.stamps;
 result := jsonb_build_object('story',story,'stamps',bonus,'duplicate',duplicate,'item',CASE WHEN item.id IS NOT NULL THEN to_jsonb(item) ELSE NULL END);
 UPDATE pet_trips SET claimed_at=now(),reward=result WHERE id=t.id;
 RETURN result;
END $$;

CREATE OR REPLACE FUNCTION redeem_travel_item(p_user_id UUID,p_item_id UUID) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE cost INTEGER;
BEGIN
 PERFORM 1 FROM profiles WHERE id=p_user_id AND role='student' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION '学生不存在'; END IF;
 SELECT stamp_cost INTO cost FROM travel_rewards WHERE item_id=p_item_id;
 IF NOT FOUND THEN RAISE EXCEPTION '无法兑换该装扮'; END IF;
 IF EXISTS(SELECT 1 FROM user_items WHERE user_id=p_user_id AND item_id=p_item_id) THEN RETURN jsonb_build_object('alreadyOwned',true); END IF;
 UPDATE travel_wallets SET stamps=stamps-cost WHERE user_id=p_user_id AND stamps>=cost;
 IF NOT FOUND THEN RAISE EXCEPTION '旅行印章不足'; END IF;
 INSERT INTO user_items(user_id,item_id) VALUES(p_user_id,p_item_id);
 RETURN jsonb_build_object('alreadyOwned',false);
END $$;

ALTER TABLE travel_destinations ENABLE ROW LEVEL SECURITY;
ALTER TABLE travel_rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE travel_wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE pet_trips ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON travel_destinations,travel_rewards,travel_wallets,pet_trips FROM anon,authenticated;
REVOKE ALL ON FUNCTION travel_state(UUID),start_pet_trip(UUID,UUID,TEXT,UUID),claim_pet_trip(UUID,UUID),redeem_travel_item(UUID,UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION travel_state(UUID),start_pet_trip(UUID,UUID,TEXT,UUID),claim_pet_trip(UUID,UUID),redeem_travel_item(UUID,UUID) TO anon,authenticated;
COMMIT;
