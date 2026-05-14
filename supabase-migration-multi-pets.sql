-- pet-paradise 多宠物支持迁移
-- 目的：允许一个学生同时持有多只宠物（满 20 级后可领养新宠物）
-- 在 Supabase SQL Editor 中执行本文件一次即可。

-- 1) 移除 pets.owner_id 的 UNIQUE 约束（若存在）
ALTER TABLE pets DROP CONSTRAINT IF EXISTS pets_owner_id_key;

-- 2) 保留 owner_id 的外键 + ON DELETE CASCADE，无需额外改动
--    如需加快按 owner_id 的多行查询，建议建立普通索引：
CREATE INDEX IF NOT EXISTS pets_owner_id_idx ON pets(owner_id);
