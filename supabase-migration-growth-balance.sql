-- 已部署项目执行本文件，将三档粮食价格更新为新版成长平衡值。
-- 宠物 XP、等级阈值和饱食度衰减由前端 constants.ts 控制，无需修改表结构。

INSERT INTO settings (key, value, updated_at)
VALUES (
  'action_costs',
  '{"basic": 5, "nice": 10, "luxury": 20}'::jsonb,
  now()
)
ON CONFLICT (key) DO UPDATE
SET value = EXCLUDED.value,
    updated_at = EXCLUDED.updated_at;
