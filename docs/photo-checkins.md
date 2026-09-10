# 自主照片打卡

学生、教师均通过独立的“打卡”导航菜单进入，分别对应 `/checkins`、`/teacher/checkins`。电脑显示在左侧菜单，手机显示在底部导航。
学生不需要选择教师发布的任务，每张照片就是一次独立打卡。教师输入 1–10000 的整数积分，也可选择不给积分。

## 规则

- 每次 1 张，每名学生每天最多成功提交 3 张，以数据库北京时间日期为准。清理、不予奖励、奖励撤销都不恢复当日次数。
- 浏览器接收 JPG/PNG/WebP 原图（最多 20 MB），Canvas 重编码为不超过 200 KiB 的 JPEG，移除原文件元数据。HEIC 需先转换。
- 上传前预留名额、实际字节数和独立对象路径。传输失败点击“重试本次提交”复用同一个 UUID；未完成预留 1 小时后失效。新选照片会创建新请求，旧预留在超时前仍暂占名额。
- 打卡存储默认上限 650,000,000 字节；容量计算包括待上传及待物理删除对象，失败不会假装释放空间。不自动覆盖旧照片。此上限只管理打卡，已有日记等仍需在 Supabase Usage 检查；如其他文件超过约 350 MB，需要下调打卡上限。
- 待审核最多 15 天，最后 2 天在教师审核页提醒；审核通过或不予奖励之后保留照片 7 天。文字、审核、奖励记录继续保存。
- 每次列表查询最多 12 条，按创建时间和 UUID 稳定分页。教师可按学生、状态、北京时间日期过滤；只能读取当前账号负责的打卡。当前项目一个教师账号对应一个班级。
- 审核在同一个数据库事务中锁定学生余额、写入 `task_completions` 和 `point_earnings`。同一打卡 ID 幂等，原有奖励总额、排行和收支流水可继续统计。教师可从原总览撤销奖励；打卡页显示“奖励已撤销”，不能通过重试再次加分。
- 历史奖励的任务引用为空，原总览显示“自主打卡 / 历史任务”，原收支记录显示通用“任务奖励”；照片详情保留具体说明。

## 身份与照片访问

现有应用采用自定义密码登录，不具备 Supabase Auth JWT。主站登录和打卡令牌使用同一个滑动会话：连续 30 分钟没有操作才过期，不限制最长连续登录时间。正常登录或注册成功时，自动用本次输入的密码向 Edge Function 换取随机令牌；登录期间检测点击、键盘、触摸、滚动及重新回到页面等活动，本地登录状态至多每 30 秒刷新，打卡令牌至多每 5 分钟续签。打卡页面不再出现单独的密码表单。令牌保存在 localStorage，可跨标签页复用，服务器仅存摘要；密码不会额外保存。每次续签和业务请求都会检查当前密码是否改变，退出时撤销并清除令牌。单账号 15 分钟最多 10 次会话签发尝试。旧版本仅保存账号 ID、没有过期时间的登录状态会失效，需要重新登录网站一次，之后进入打卡页无需再次登录。打卡服务未部署或不可用时不阻断其他功能登录。

新增表、RPC 仅允许 service_role；私有 bucket 没有开放的客户端读写策略。访问图像使用 10 分钟有效的签名 URL，持有此 URL 的人可在有效期内访问，因此不要分享链接。密钥只放 Edge Function，不放 VITE 环境变量。

**现有身份系统的限制：** 旧项目 `profiles` 及部分业务表/RPC 使用开放 RLS，并允许客户端直接读写资料，原密码摘要、角色和班级归属未获得可靠的服务端保护。本次新增会话和私有 bucket 不能消除旧接口篡改资料造成的冒用风险。正式收集学生私密照片前应统一迁移 Supabase Auth / 可信后端并收紧旧资料表权限；不要把这次的身份校验视为整站安全整改已经完成。不能直接禁用旧 profiles 读写，否则会破坏现有登录和管理流程。

## 上线顺序

1. 已有项目在 SQL Editor 执行根目录 `supabase-migration-photo-checkins.sql`。依赖已有课堂积分表及撤销字段（`supabase-migration-classroom.sql`、`supabase-migration-revoke-awards.sql`）。新安装执行更新后的 `supabase-schema.sql` 已包含打卡迁移。
2. 用 Supabase CLI 登录并选择正确项目。设置一个随机、至少 32 字节的 `PHOTO_CHECKIN_CLEANUP_SECRET`，保存在 Edge Function Secrets。`SUPABASE_URL` 和 `SUPABASE_SERVICE_ROLE_KEY` 使用运行平台提供的服务端环境变量。
3. 从项目根目录部署：`supabase functions deploy photo-checkins --project-ref <实际项目编号>`。`supabase/config.toml` 为该函数禁用平台 JWT 校验，因为函数内部使用自定义会话；不能删除函数内部校验。
4. 在 Vault 创建 `photo_checkins_project_url` 和 `photo_checkins_cleanup_secret`，然后执行 `supabase/photo-checkins-cron.sql`。每天北京时间 03:00 清理，每次最多 500 张。
5. 发布前端（现有 Docker/Vite 发布流程）。没有部署函数或迁移时，页面会报功能未部署/服务不可用，不开放上传。

容量调整（字节）：

```sql
UPDATE photo_checkin_settings SET max_bytes=650000000 WHERE id=true;
```

## 清理验证

清理器先使到期 pending 记录过期、uploading 记录失败，再调用 Storage remove 真正删除文件，最后设置 `photo_deleted_at`。任何失败保留路径供下一轮重试；只删数据库行不会释放 Storage。不要手工删除 `storage.objects`。

调度成功仅表示 HTTP 请求入队，不代表文件已删除。部署后手动调用一次清理函数（带 `x-cleanup-secret` 请求头），确认 HTTP 200 和返回的 deleted 数；再检查 `net._http_response` HTTP 结果、Edge Function 日志和 Storage 对象。禁止在日志中输出密钥或照片请求体。

```sql
SELECT jobid,jobname,schedule,active FROM cron.job WHERE jobname='photo-checkins-daily-cleanup';
SELECT status_code,timed_out,error_msg,created FROM net._http_response ORDER BY created DESC LIMIT 10;
SELECT status,count(*),sum(bytes) FROM photo_checkins WHERE photo_deleted_at IS NULL GROUP BY status;
SELECT count(*) AS cleanup_backlog FROM photo_checkins WHERE photo_deleted_at IS NULL AND expires_at<=now();
```

删除学生/教师时照片记录的外键置空，清理器仍能找到文件。数据库/对象备份若另有副本，须按备份系统自己的保留策略清理。

## 本地验证

- `node scripts/test-photo-checkins-db.mjs`：需 `@electric-sql/pglite`，或设置 `PGLITE_MODULE` 指向其入口。使用隔离 PostgreSQL，验证迁移重跑、名额预留、跨日、容量、权限、事务回滚、重复奖励、撤销及清理重试。
- `node scripts/check-photo-checkins-edge.mjs`：使用项目 TypeScript 和 Supabase 客户端类型检查函数；Deno 全局用声明替代，不代表云运行验收。
- 启动 `vite --host 127.0.0.1 --port 5193`，运行 `node scripts/test-photo-checkins-ui.mjs`；需 Playwright/Chrome，可用 `PLAYWRIGHT_MODULE` 指定已有安装。用真实 Vue 页面和隔离接口夹具验证压缩上传、每日三张、审核、结果、异常重试及响应式布局。

以上测试不访问线上学生数据，不替代真实 Supabase Storage、Edge Function、Cron 端到端验收。
