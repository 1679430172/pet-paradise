# 班级宠物乐园（pet-paradise）

面向班级场景的“学生养宠 + 教师管理 + 任务积分”Web 应用。前端使用 Vue 3、TypeScript、Vite 和 Pinia，数据、RPC、RLS 与文件存储使用 Supabase。

本文档是项目唯一部署说明，按全新环境从零部署编写。数据库只保留一个入口：[`supabase-schema.sql`](./supabase-schema.sql)。

## 一、功能概览

- 学生、教师、管理员三类角色
- 多宠物领养、喂养、等级和形态成长
- 成长日记、点赞、任务奖励与积分收支
- 本周成长榜、课堂大屏和奖励撤销
- 商城装扮、旅行、旅行券、明信片与历史快照
- 自主照片打卡、教师审核和定时清理
- 班级功能开关和多类型公告

## 二、仓库结构

```text
src/                              Vue 前端
public/assets/                    宠物、商城和旅行素材
supabase-schema.sql               唯一的完整数据库 SQL
supabase/functions/photo-checkins 照片打卡 Edge Function
scripts/                          本地验证脚本
certs/                            Docker HTTPS 证书目录
Dockerfile                        前端构建和 Nginx 镜像
docker-compose.yml                Docker 部署配置
nginx.conf                        HTTPS、SPA 和健康检查配置
.github/workflows/deploy.yml      GitHub Pages 工作流
```

## 三、部署前准备

需要 Node.js 20/22、一个全新的 Supabase 项目，以及按部署方式选择的 Supabase CLI、Docker、域名和证书。

复制 `.env.example` 为 `.env`，填写：

```env
VITE_SUPABASE_URL=https://<project-ref>.supabase.co
VITE_SUPABASE_ANON_KEY=<anon-key>
APP_PORT=80
HTTPS_PORT=443
```

Supabase URL 和 anon key 可在 Dashboard → Project Settings → API 获取。`VITE_` 变量会在构建时写入静态文件，修改后必须重新构建。

## 四、初始化 Supabase

1. 打开新 Supabase 项目的 SQL Editor。
2. 复制 [`supabase-schema.sql`](./supabase-schema.sql) 的全部内容。
3. 整段执行一次并确认没有错误。
4. 不需要再执行其他项目 SQL 文件。

该脚本会创建当前项目需要的表、索引、函数、触发器、RLS 策略、Storage bucket、基础配置和默认管理员。

执行后可做基础检查：

```sql
select table_name from information_schema.tables
where table_schema = 'public' order by table_name;

select routine_name from information_schema.routines
where routine_schema = 'public' order by routine_name;

select tablename, policyname, cmd from pg_policies
where schemaname = 'public' order by tablename, policyname;
```

默认管理员为 `admin / 147258369lss`。当前管理页面不能修改管理员自己的密码，因此正式开放服务前，必须在 SQL Editor 将管理员密码更新为新密码的摘要；不要长期使用默认密码。摘要算法与前端一致：`SHA-256(新密码 + 'pet-paradise-salt')`。

```sql
update profiles
set password = '<上面算法生成的 SHA-256 十六进制摘要>'
where username = 'admin' and role = 'teacher' and is_admin = true;
```

## 五、部署照片打卡 Edge Function

照片打卡表和私有 bucket 已包含在完整 SQL 中，但上传、审核和清理还依赖 Edge Function。

```bash
supabase login
supabase secrets set PHOTO_CHECKIN_CLEANUP_SECRET=<至少32字节的随机密钥> --project-ref <project-ref>
supabase functions deploy photo-checkins --project-ref <project-ref>
```

`supabase/config.toml` 已为该函数关闭平台 JWT 校验，因为项目使用自定义账号会话；函数内部仍会校验自己的会话令牌。`SUPABASE_URL` 和 `SUPABASE_SERVICE_ROLE_KEY` 使用 Supabase 运行环境提供的服务端变量，不能放进前端 `.env`。

### 可选：每天自动清理

先在 Supabase Vault 创建：

- `photo_checkins_project_url`：`https://<project-ref>.supabase.co`
- `photo_checkins_cleanup_secret`：与 Function Secret 相同的密钥

然后在 SQL Editor 执行以下环境专属配置：

```sql
create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;

do $$
begin
  if not exists (select 1 from vault.decrypted_secrets where name='photo_checkins_project_url')
     or not exists (select 1 from vault.decrypted_secrets where name='photo_checkins_cleanup_secret') then
    raise exception '请先在 Vault 配置照片清理的项目地址和密钥';
  end if;
end $$;

select cron.schedule(
  'photo-checkins-daily-cleanup', '0 19 * * *',
  $job$
    select net.http_post(
      url := (select decrypted_secret from vault.decrypted_secrets where name='photo_checkins_project_url' limit 1) || '/functions/v1/photo-checkins',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-cleanup-secret', (select decrypted_secret from vault.decrypted_secrets where name='photo_checkins_cleanup_secret' limit 1)
      ),
      body := '{"action":"cleanup"}'::jsonb,
      timeout_milliseconds := 120000
    );
  $job$
);
```

`0 19 * * *` 是 UTC 19:00，即北京时间次日 03:00。调度成功只表示请求会发出，还应检查 Edge Function 日志、Storage 对象和 `net._http_response`。

## 六、本地运行

```bash
npm ci
npm run dev
```

生产构建与预览：

```bash
npm run build
npm run preview
```

至少验证管理员登录和创建教师、教师创建学生和发奖、学生领养和喂养，以及照片上传和审核。构建成功不代表 Supabase、Storage、Edge Function 或浏览器业务流程已经可用。

## 七、Docker + Nginx 部署

将 Nginx 格式证书放到：

```text
certs/fullchain.crt   # 证书包中的 *_bundle.crt
certs/private.key     # 证书包中的 *.key
```

证书和私钥已被 Git 忽略。Linux 主机执行：

```bash
chmod 600 certs/private.key
chmod 644 certs/fullchain.crt
docker compose up -d --build
```

检查容器、日志、HTTP 和 HTTPS：

```bash
docker compose ps
docker compose logs --tail=100 pet-paradise
curl -I http://127.0.0.1/healthz
curl -I http://127.0.0.1
curl -Ik https://127.0.0.1/healthz
```

`nginx.conf` 当前还包含 `13.231.205.217` 的 Let's Encrypt 证书路径。部署前确认目标主机存在：

```text
/etc/letsencrypt/live/13.231.205.217/fullchain.pem
/etc/letsencrypt/live/13.231.205.217/privkey.pem
```

目标服务器或 IP 不同时，应先修改对应的 Nginx server 配置。容器显示 `healthy` 只证明容器内健康端点正常，不代表公网 DNS、HTTPS 证书或 Supabase 请求正常。

后续更新：

```bash
git pull
docker compose up -d --build
docker compose ps
docker compose logs --tail=100 pet-paradise
curl -I http://127.0.0.1/healthz
```

## 八、GitHub Pages

`.github/workflows/deploy.yml` 会在代码推送到 `master` 后发布 GitHub Pages。当前工作流没有注入 Supabase Secrets，会使用 `src/lib/supabase.ts` 的回退配置。要连接其他 Supabase 项目，应先在 GitHub Actions 中显式传入 `VITE_SUPABASE_URL` 和 `VITE_SUPABASE_ANON_KEY`。

## 九、核心规则与安全边界

- 项目使用自定义用户名密码，不依赖 Supabase Auth。
- 学生账号在同一教师班级内不能重名，不同班级可以重名。
- 徽章属于账号，多个宠物共享账号徽章。
- 每只宠物独立旅行；旅行券、装扮和明信片收藏归学生账号共享。
- 宠物旅行时暂停饱食度衰减，归来后继续计算。
- 公告支持类型、结束时间和历史，每次登录会话展示一次。
- 照片打卡使用私有 Storage 和短时签名 URL；service role key 只能存在于 Edge Function。
- 当前自定义认证不是完整的服务端身份体系。正式收集学生私密照片前，应评估迁移 Supabase Auth 或可信后端并收紧旧业务表权限。

## 十、宠物素材

每个宠物种类使用 20 张等级图：

```text
public/assets/pets/<species>/Lv_01.png
...
public/assets/pets/<species>/Lv_20.png
```

新增种类时同步修改 `src/lib/constants.ts` 的 `PET_SPECIES` 和 `PET_SPECIES_LABELS`。图片必须位于 `public/`，否则 `/assets/...` 的运行时路径无法读取。

## 十一、最终验收

- `supabase-schema.sql` 在目标新项目完整执行成功
- 表、函数、RLS 和 Storage bucket 已检查
- 照片打卡 Edge Function 已完成真实上传和审核验证
- 如启用定时清理，Cron 请求和实际对象删除均已验证
- `.env` 指向正确项目，并已重新构建
- 本地构建或 Docker 镜像构建成功
- HTTP、HTTPS、域名和证书分别通过检查
- 管理员、教师、学生的核心流程均完成浏览器验证
