-- 班级（老师账号）级增值功能：现有班级保持全开，新建班级默认关闭。
CREATE TABLE IF NOT EXISTS tenant_features (
  tenant_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  feature_key TEXT NOT NULL CHECK (feature_key IN ('travel','photo_checkin','shop')),
  enabled BOOLEAN NOT NULL DEFAULT false,
  enabled_at TIMESTAMPTZ,
  enabled_by UUID REFERENCES profiles(id) ON DELETE SET NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, feature_key)
);

ALTER TABLE tenant_features ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON tenant_features FROM anon, authenticated;

-- 迁移上线前已经存在的班级不改变现有体验。
INSERT INTO tenant_features(tenant_id, feature_key, enabled, enabled_at)
SELECT p.id, f.feature_key, true, now()
FROM profiles p
CROSS JOIN (VALUES ('travel'),('photo_checkin'),('shop')) AS f(feature_key)
WHERE p.role='teacher' AND NOT p.is_admin
ON CONFLICT (tenant_id, feature_key) DO NOTHING;

CREATE OR REPLACE FUNCTION get_tenant_features(p_tenant_id UUID)
RETURNS TABLE(feature_key TEXT, enabled BOOLEAN)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
  SELECT f.feature_key, COALESCE(tf.enabled,false)
  FROM (VALUES ('travel'),('photo_checkin'),('shop')) AS f(feature_key)
  LEFT JOIN tenant_features tf ON tf.tenant_id=p_tenant_id AND tf.feature_key=f.feature_key;
$$;

CREATE OR REPLACE FUNCTION set_tenant_feature(p_admin_id UUID,p_tenant_id UUID,p_feature_key TEXT,p_enabled BOOLEAN)
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
BEGIN
  IF p_feature_key NOT IN ('travel','photo_checkin','shop') THEN RAISE EXCEPTION '未知的班级功能'; END IF;
  IF NOT EXISTS(SELECT 1 FROM profiles WHERE id=p_admin_id AND role='teacher' AND is_admin) THEN RAISE EXCEPTION '仅管理员可修改班级功能'; END IF;
  IF NOT EXISTS(SELECT 1 FROM profiles WHERE id=p_tenant_id AND role='teacher' AND NOT is_admin) THEN RAISE EXCEPTION '班级不存在'; END IF;
  INSERT INTO tenant_features(tenant_id,feature_key,enabled,enabled_at,enabled_by,updated_at)
  VALUES(p_tenant_id,p_feature_key,p_enabled,CASE WHEN p_enabled THEN now() END,p_admin_id,now())
  ON CONFLICT(tenant_id,feature_key) DO UPDATE SET enabled=EXCLUDED.enabled,
    enabled_at=CASE WHEN EXCLUDED.enabled THEN now() ELSE tenant_features.enabled_at END,
    enabled_by=EXCLUDED.enabled_by,updated_at=now();
  RETURN p_enabled;
END;
$$;

CREATE OR REPLACE FUNCTION tenant_feature_enabled(p_profile_id UUID,p_feature_key TEXT)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$
  SELECT COALESCE((
    SELECT tf.enabled FROM profiles p
    JOIN tenant_features tf ON tf.tenant_id=CASE WHEN p.role='teacher' THEN p.id ELSE p.teacher_id END
    WHERE p.id=p_profile_id AND tf.feature_key=p_feature_key
  ),false);
$$;

CREATE OR REPLACE FUNCTION guard_tenant_feature_write() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE profile_id UUID; required_feature TEXT;
BEGIN
  IF TG_TABLE_NAME='shop_orders' THEN profile_id:=NEW.buyer_id; required_feature:='shop';
  ELSIF TG_TABLE_NAME='pet_trips' THEN profile_id:=NEW.user_id; required_feature:='travel';
  ELSE RETURN NEW;
  END IF;
  IF NOT tenant_feature_enabled(profile_id,required_feature) THEN RAISE EXCEPTION '本班级尚未开通此功能'; END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION guard_tenant_item_write() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$
DECLARE profile_id UUID; acquisition_value TEXT; item_id UUID;
BEGIN
  IF TG_TABLE_NAME='user_items' THEN
    profile_id:=NEW.user_id; item_id:=NEW.item_id;
  ELSIF TG_TABLE_NAME='pet_cosmetics' THEN
    SELECT owner_id INTO profile_id FROM pets WHERE id=NEW.pet_id;
    IF TG_OP='INSERT' OR NEW.frame_item_id IS DISTINCT FROM OLD.frame_item_id THEN item_id:=NEW.frame_item_id;
    ELSIF TG_OP='INSERT' OR NEW.background_item_id IS DISTINCT FROM OLD.background_item_id THEN item_id:=NEW.background_item_id;
    ELSE RETURN NEW;
    END IF;
  END IF;
  IF item_id IS NULL THEN RETURN NEW; END IF;
  SELECT acquisition INTO acquisition_value FROM shop_items WHERE id=item_id;
  IF acquisition_value='travel' AND NOT tenant_feature_enabled(profile_id,'travel') THEN RAISE EXCEPTION '本班级尚未开通旅游功能'; END IF;
  IF COALESCE(acquisition_value,'shop')='shop' AND NOT tenant_feature_enabled(profile_id,'shop') THEN RAISE EXCEPTION '本班级尚未开通宠物商城'; END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS guard_shop_feature ON shop_orders;
CREATE TRIGGER guard_shop_feature BEFORE INSERT ON shop_orders FOR EACH ROW EXECUTE FUNCTION guard_tenant_feature_write();
DROP TRIGGER IF EXISTS guard_travel_feature ON pet_trips;
CREATE TRIGGER guard_travel_feature BEFORE INSERT ON pet_trips FOR EACH ROW EXECUTE FUNCTION guard_tenant_feature_write();
DROP TRIGGER IF EXISTS guard_owned_item_feature ON user_items;
CREATE TRIGGER guard_owned_item_feature BEFORE INSERT ON user_items FOR EACH ROW EXECUTE FUNCTION guard_tenant_item_write();
DROP TRIGGER IF EXISTS guard_cosmetic_feature ON pet_cosmetics;
CREATE TRIGGER guard_cosmetic_feature BEFORE INSERT OR UPDATE ON pet_cosmetics FOR EACH ROW EXECUTE FUNCTION guard_tenant_item_write();

REVOKE ALL ON FUNCTION get_tenant_features(UUID),set_tenant_feature(UUID,UUID,TEXT,BOOLEAN),tenant_feature_enabled(UUID,TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_tenant_features(UUID),set_tenant_feature(UUID,UUID,TEXT,BOOLEAN),tenant_feature_enabled(UUID,TEXT) TO anon,authenticated,service_role;
