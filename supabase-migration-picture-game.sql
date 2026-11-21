BEGIN;

ALTER TABLE public.tenant_features DROP CONSTRAINT IF EXISTS tenant_features_feature_key_check;
ALTER TABLE public.tenant_features ADD CONSTRAINT tenant_features_feature_key_check
  CHECK (feature_key IN ('travel','photo_checkin','shop','geometry_game','picture_game'));

CREATE OR REPLACE FUNCTION get_tenant_features(p_tenant_id UUID) RETURNS TABLE(feature_key TEXT,enabled BOOLEAN)
 LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $$ SELECT f.feature_key,COALESCE(tf.enabled,false) FROM (VALUES('travel'),('photo_checkin'),('shop'),('geometry_game'),('picture_game')) f(feature_key) LEFT JOIN tenant_features tf ON tf.tenant_id=p_tenant_id AND tf.feature_key=f.feature_key $$;
CREATE OR REPLACE FUNCTION set_tenant_feature(p_admin_id UUID,p_tenant_id UUID,p_feature_key TEXT,p_enabled BOOLEAN) RETURNS BOOLEAN
 LANGUAGE plpgsql SECURITY DEFINER SET search_path=public AS $$ BEGIN
 IF p_feature_key NOT IN ('travel','photo_checkin','shop','geometry_game','picture_game') THEN RAISE EXCEPTION '未知的班级功能'; END IF;
 IF NOT EXISTS(SELECT 1 FROM profiles WHERE id=p_admin_id AND role='teacher' AND is_admin) THEN RAISE EXCEPTION '仅管理员可修改班级功能'; END IF;
 IF NOT EXISTS(SELECT 1 FROM profiles WHERE id=p_tenant_id AND role='teacher' AND NOT is_admin) THEN RAISE EXCEPTION '班级不存在'; END IF;
 INSERT INTO tenant_features(tenant_id,feature_key,enabled,enabled_at,enabled_by,updated_at) VALUES(p_tenant_id,p_feature_key,p_enabled,CASE WHEN p_enabled THEN now() END,p_admin_id,now())
 ON CONFLICT(tenant_id,feature_key) DO UPDATE SET enabled=EXCLUDED.enabled,enabled_at=CASE WHEN EXCLUDED.enabled THEN now() ELSE tenant_features.enabled_at END,enabled_by=EXCLUDED.enabled_by,updated_at=now(); RETURN p_enabled; END $$;

COMMIT;
