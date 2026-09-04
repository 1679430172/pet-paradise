-- 商城：卡片边框、背景、拥有关系、装备状态与购买记录。
-- 可重复执行。部署前端前先在 Supabase SQL Editor 执行本文件。
BEGIN;

CREATE TABLE IF NOT EXISTS shop_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  category TEXT NOT NULL CHECK (category IN ('frame', 'background')),
  style_key TEXT NOT NULL,
  price INTEGER NOT NULL CHECK (price >= 0),
  icon TEXT NOT NULL DEFAULT '✨',
  sort_order INTEGER NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(category, style_key)
);

CREATE TABLE IF NOT EXISTS shop_orders (
  id UUID PRIMARY KEY,
  buyer_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  item_id UUID NOT NULL REFERENCES shop_items(id),
  price INTEGER NOT NULL CHECK (price >= 0),
  balance_after INTEGER NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(buyer_id, item_id)
);

CREATE TABLE IF NOT EXISTS user_items (
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  item_id UUID NOT NULL REFERENCES shop_items(id),
  order_id UUID NOT NULL REFERENCES shop_orders(id),
  acquired_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY(user_id, item_id)
);

CREATE TABLE IF NOT EXISTS pet_cosmetics (
  pet_id UUID PRIMARY KEY REFERENCES pets(id) ON DELETE CASCADE,
  frame_item_id UUID REFERENCES shop_items(id) ON DELETE SET NULL,
  background_item_id UUID REFERENCES shop_items(id) ON DELETE SET NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS shop_orders_buyer_created_idx ON shop_orders(buyer_id, created_at DESC);
CREATE INDEX IF NOT EXISTS user_items_user_idx ON user_items(user_id);

ALTER TABLE shop_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE shop_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE pet_cosmetics ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "允许查看商品" ON shop_items;
CREATE POLICY "允许查看商品" ON shop_items FOR SELECT USING (true);
DROP POLICY IF EXISTS "允许查看购买记录" ON shop_orders;
CREATE POLICY "允许查看购买记录" ON shop_orders FOR SELECT USING (true);
DROP POLICY IF EXISTS "允许查看已有装扮" ON user_items;
CREATE POLICY "允许查看已有装扮" ON user_items FOR SELECT USING (true);
DROP POLICY IF EXISTS "允许查看当前装扮" ON pet_cosmetics;
CREATE POLICY "允许查看当前装扮" ON pet_cosmetics FOR SELECT USING (true);

INSERT INTO shop_items(slug,name,description,category,style_key,price,icon,sort_order) VALUES
  ('frame-leaf','森语藤蔓','清新的叶片环绕卡片','frame','leaf',35,'🌿',10),
  ('frame-candy','糖果泡泡','柔软明亮的糖果色边框','frame','candy',55,'🍬',20),
  ('frame-starlight','星光流转','闪耀的蓝紫星光边框','frame','starlight',90,'🌟',30),
  ('frame-gold','荣耀金冠','为坚持成长的宠物加冕','frame','gold',160,'👑',40),
  ('background-meadow','晨光草地','像在清晨的草地上散步','background','meadow',30,'🌱',110),
  ('background-sunset','蜜桃晚霞','温暖柔和的粉橙晚霞','background','sunset',50,'🌅',120),
  ('background-ocean','海盐气泡','清凉的海蓝色波光','background','ocean',75,'🌊',130),
  ('background-night','银河夜游','深蓝星河中的安静旅程','background','night',120,'🌌',140),
  ('background-hidden','隐藏背景','去掉主题背景，保持简洁透明','background','hidden',20,'🪟',150)
ON CONFLICT (slug) DO UPDATE SET
  name=EXCLUDED.name,description=EXCLUDED.description,category=EXCLUDED.category,
  style_key=EXCLUDED.style_key,price=EXCLUDED.price,icon=EXCLUDED.icon,sort_order=EXCLUDED.sort_order;

CREATE OR REPLACE FUNCTION purchase_shop_item(
  p_buyer_id UUID, p_item_id UUID, p_request_id UUID
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE buyer profiles%ROWTYPE; item shop_items%ROWTYPE; existing shop_orders%ROWTYPE;
BEGIN
  IF p_buyer_id IS NULL OR p_item_id IS NULL OR p_request_id IS NULL THEN RAISE EXCEPTION '无效的购买请求'; END IF;
  SELECT * INTO buyer FROM profiles WHERE id=p_buyer_id AND role='student' FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION '学生不存在'; END IF;
  SELECT * INTO existing FROM shop_orders WHERE id=p_request_id;
  IF FOUND THEN
    IF existing.buyer_id IS DISTINCT FROM p_buyer_id OR existing.item_id IS DISTINCT FROM p_item_id THEN RAISE EXCEPTION '请求编号已用于其他购买'; END IF;
    RETURN jsonb_build_object('balance',existing.balance_after,'order',to_jsonb(existing),'alreadyOwned',false);
  END IF;
  IF EXISTS(SELECT 1 FROM user_items WHERE user_id=p_buyer_id AND item_id=p_item_id) THEN
    RETURN jsonb_build_object('balance',buyer.points,'alreadyOwned',true);
  END IF;
  -- 商品目录只有公开读取策略；FOR SHARE 会额外触发行级锁权限并被 RLS 过滤。
  -- 价格以购买事务读取到的当前值为准，无需锁定商品目录行。
  SELECT * INTO item FROM shop_items WHERE id=p_item_id AND is_active=true;
  IF NOT FOUND THEN RAISE EXCEPTION '商品已下架'; END IF;
  IF COALESCE(buyer.points,0) < item.price THEN RAISE EXCEPTION '积分不足，需要 % 积分',item.price; END IF;
  UPDATE profiles SET points=COALESCE(points,0)-item.price WHERE id=p_buyer_id RETURNING * INTO buyer;
  INSERT INTO shop_orders(id,buyer_id,item_id,price,balance_after)
    VALUES(p_request_id,p_buyer_id,item.id,item.price,buyer.points) RETURNING * INTO existing;
  INSERT INTO user_items(user_id,item_id,order_id) VALUES(p_buyer_id,item.id,existing.id);
  RETURN jsonb_build_object('balance',buyer.points,'order',to_jsonb(existing),'alreadyOwned',false);
END $$;

CREATE OR REPLACE FUNCTION equip_pet_cosmetic(
  p_actor_id UUID, p_pet_id UUID, p_category TEXT, p_item_id UUID DEFAULT NULL
) RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE item shop_items%ROWTYPE; equipped pet_cosmetics%ROWTYPE;
BEGIN
  IF p_category NOT IN ('frame','background') THEN RAISE EXCEPTION '无效的装扮类型'; END IF;
  IF NOT EXISTS(SELECT 1 FROM pets WHERE id=p_pet_id AND owner_id=p_actor_id)
    OR NOT EXISTS(SELECT 1 FROM profiles WHERE id=p_actor_id AND role='student') THEN RAISE EXCEPTION '只能装扮自己的宠物'; END IF;
  IF p_item_id IS NOT NULL THEN
    SELECT i.* INTO item FROM shop_items i JOIN user_items u ON u.item_id=i.id
      WHERE i.id=p_item_id AND u.user_id=p_actor_id AND i.category=p_category;
    IF NOT FOUND THEN RAISE EXCEPTION '尚未拥有该装扮'; END IF;
  END IF;
  INSERT INTO pet_cosmetics(pet_id,frame_item_id,background_item_id)
    VALUES(p_pet_id,CASE WHEN p_category='frame' THEN p_item_id END,CASE WHEN p_category='background' THEN p_item_id END)
  ON CONFLICT (pet_id) DO UPDATE SET
    frame_item_id=CASE WHEN p_category='frame' THEN p_item_id ELSE pet_cosmetics.frame_item_id END,
    background_item_id=CASE WHEN p_category='background' THEN p_item_id ELSE pet_cosmetics.background_item_id END,
    updated_at=now()
  RETURNING * INTO equipped;
  RETURN to_jsonb(equipped);
END $$;

GRANT SELECT ON shop_items,shop_orders,user_items,pet_cosmetics TO anon,authenticated;
REVOKE INSERT, UPDATE, DELETE ON shop_orders,user_items,pet_cosmetics FROM anon,authenticated;
GRANT EXECUTE ON FUNCTION purchase_shop_item(UUID,UUID,UUID),equip_pet_cosmetic(UUID,UUID,TEXT,UUID) TO anon,authenticated;
COMMIT;
