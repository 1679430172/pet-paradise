-- 将徽章从宠物维度归并为账号维度。可重复执行。
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS badges JSONB NOT NULL DEFAULT '[]'::jsonb;

CREATE OR REPLACE FUNCTION sync_pet_badges_to_profile() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  UPDATE profiles profile
  SET badges = (
    SELECT COALESCE(jsonb_agg(DISTINCT badge), '[]'::jsonb)
    FROM jsonb_array_elements_text(
      COALESCE(profile.badges, '[]'::jsonb) || COALESCE(NEW.badges, '[]'::jsonb)
    ) AS item(badge)
  )
  WHERE profile.id = NEW.owner_id;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS sync_pet_badges_to_profile ON pets;
CREATE TRIGGER sync_pet_badges_to_profile
AFTER INSERT OR UPDATE OF badges ON pets
FOR EACH ROW EXECUTE FUNCTION sync_pet_badges_to_profile();

-- 补一次回填，确保迁移前已经存在的所有宠物徽章都进入账号。
UPDATE profiles profile
SET badges = COALESCE((
  SELECT jsonb_agg(DISTINCT badge)
  FROM (
    SELECT jsonb_array_elements_text(COALESCE(profile.badges, '[]'::jsonb)) AS badge
    UNION
    SELECT jsonb_array_elements_text(COALESCE(pet.badges, '[]'::jsonb)) AS badge
    FROM pets pet WHERE pet.owner_id = profile.id
  ) merged
), '[]'::jsonb);
