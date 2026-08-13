# 班级宠物乐园（pet-paradise）

面向班级场景的"学生养宠 + 教师代管 + 任务积分"轻量级 Web 应用。学生通过完成任务获得积分，用积分喂养宠物以提升等级与形态；教师可代管学生、配置任务和积分消耗。

> 本文档为**新部署**指南。所有历史迁移脚本已合并为单文件 [`supabase-schema.sql`](./supabase-schema.sql)。

---

## 一、功能概览

- **角色**：学生 / 教师，单库共存，登录时区分入口
- **宠物**：每只 1~20 级，5 个形态阶段（蛋 / 幼年 / 青年 / 成年 / 完全体），满 20 级后可领养下一只
- **喂食**：仅一个状态（饱食度 hunger），通过三档"食物"消耗不同积分
  | 档位 | icon | 默认积分 | hunger+ | xp+ |
  |---|---|---|---|---|
  | 普通粮 | 🍖 | 3 | 20 | 5 |
  | 营养粮 | 🍗 | 8 | 50 | 12 |
  | 豪华粮 | 🥩 | 15 | 100 | 25 |
- **日记 / 点赞**：学生可发成长日记并互相点赞，每日首篇日记奖励积分
- **任务系统**：教师创建任务并定义奖励积分；可记录学生完成情况
- **教师端**：学生列表、单学生详情、宠物卡片视图（横向 Grid + 卡内左右切换多宠物）、任务管理、积分消耗设置

---

## 二、技术栈

- 前端：Vue 3.5 `<script setup>` + TypeScript + Vite + Pinia + Vue Router
- 后端：Supabase（PostgreSQL + Row Level Security + Storage）
- 部署：Docker + Nginx / Cloudflare Pages / 任意静态托管

### Docker + Nginx 部署

复制环境变量并填写 Supabase 配置：

```bash
cp .env.example .env
```

默认使用宿主机 `80` 端口启动：

```bash
docker compose up -d --build
```

访问 `http://服务器IP`。如需修改端口，在 `.env` 中设置 `APP_PORT=8080` 后重新启动。

常用维护命令：

```bash
docker compose ps
docker compose logs -f
docker compose up -d --build
docker compose down
```

`VITE_SUPABASE_URL` 和 `VITE_SUPABASE_ANON_KEY` 会在前端构建阶段写入静态文件，修改后必须重新构建镜像。

---

## 三、目录结构（核心）

```
src/
├── components/
│   ├── common/BottomNav.vue
│   ├── pet/PetAvatar.vue          # 宠物图片组件（按 species + level 取图，失败回退 emoji）
│   └── teacher/TeacherNav.vue
├── lib/
│   ├── constants.ts               # 单一事实源：宠物种类/等级/形态/动作/积分
│   └── supabase.ts
├── pages/
│   ├── HomePage.vue               # 学生主页（宠物 + 三档喂食按钮）
│   ├── LoginPage.vue / RegisterPage.vue
│   ├── PetCreatePage.vue          # 领养新宠物
│   ├── DiaryPage.vue / DiaryEditorPage.vue / DiaryDetailPage.vue
│   ├── FeedPage.vue / ProfilePage.vue
│   └── teacher/
│       ├── TeacherDashboard.vue
│       ├── TeacherStudents.vue / TeacherStudentDetail.vue
│       ├── TeacherPets.vue        # 学生宠物卡片视图（核心 UI）
│       ├── TeacherTasks.vue / TeacherTaskForm.vue
│       ├── TeacherStats.vue
│       └── TeacherSettings.vue    # 三档喂食积分配置 + 日记奖励配置
├── stores/                        # Pinia：auth / pet / diary / feed / points / tasks / teacher
└── router/index.ts
public/
└── assets/pets/<species>/Lv_01.png ~ Lv_20.png
supabase-schema.sql                # ← 新部署唯一 SQL
```

---

## 四、新部署完整步骤

### 1. 创建 Supabase 项目并执行 SQL

1. 在 [Supabase](https://supabase.com) 新建项目
2. 进入 **SQL Editor**，把 [`supabase-schema.sql`](./supabase-schema.sql) 的全部内容粘贴进去并 **Run**
3. 该脚本会一次性完成：建表、索引、RLS 策略、Storage bucket、预置 settings、预置教师账号
4. 默认教师账号：用户名 `teacher`，密码 `teacher123`（**首次登录后请立即在系统内修改密码**）

### 2. 配置环境变量

复制 `.env.example` 为 `.env`，填入：
```env
VITE_SUPABASE_URL=https://<your-project>.supabase.co
VITE_SUPABASE_ANON_KEY=<your-anon-key>
```
两者均可在 Supabase Dashboard → **Project Settings → API** 中获取。

### 3. 准备宠物素材

每个宠物种类需要 20 张等级图，命名 `Lv_01.png ~ Lv_20.png`（两位数补零），路径：
```
public/assets/pets/<species>/Lv_01.png
public/assets/pets/<species>/Lv_02.png
...
public/assets/pets/<species>/Lv_20.png
```
> 必须放在 `public/` 下：Vite 仅从 public 目录按绝对 URL 提供静态资源；放在 `src/assets/` 下不会被 `<img src="/...">` 解析。

当前仓库内置素材：`public/assets/pets/紫电龙/`。

### 4. 安装依赖与启动

```bash
npm install
npm run dev      # 本地开发
npm run build    # 生产构建
npm run preview  # 预览构建产物
```

---

## 五、宠物种类扩展指南

新增一个宠物种类（例：`焰狐`）需要 4 步：

1. 准备 20 张图片放到 `public/assets/pets/焰狐/Lv_01.png ~ Lv_20.png`
2. 编辑 [`src/lib/constants.ts`](./src/lib/constants.ts)：
   ```ts
   export const PET_SPECIES = ['紫电龙', '焰狐'] as const
   export const PET_SPECIES_LABELS: Record<PetSpecies, string> = {
     紫电龙: '紫电龙',
     焰狐: '焰狐',
   }
   ```
3. （可选，提升体验）在以下三处的 `speciesIcons` 与 [`PetAvatar.vue`](./src/components/pet/PetAvatar.vue) 的 `SPECIES_EMOJI` 添加 emoji 备选（图片加载失败时显示）：
   - `src/pages/PetCreatePage.vue`
   - `src/pages/teacher/TeacherPets.vue`
   - `src/pages/teacher/TeacherStudentDetail.vue`
4. 无需任何数据库改动。`getPetImage` 会按 species 自动拼路径。

---

## 六、关键约束与设计要点

- **数据模型保留字段**：`pets.happiness / cleanliness / last_played_at / last_cleaned_at` 为历史字段，前端不再读写但保留以兼容旧数据；如需清理可手动 DROP
- **统一 fallback**：`getPetImage` 对未知 species（旧数据库历史值）自动回退到 `PET_SPECIES[0]`；图片加载失败则在 `PetAvatar` 内回退到对应 emoji
- **多宠物**：`pets.owner_id` 无 UNIQUE 约束；满 20 级才能继续领养下一只
- **形态阶段**：Lv.1-3 蛋 / 4-8 幼年 / 9-13 青年 / 14-19 成年 / 20 完全体（详见 `getPetStage`）
- **积分配置可在线修改**：教师端 → 积分设置；保存到 `settings` 表，前端读取做了"旧 `{feed,play,clean}` 格式自动回退默认值"的兼容
- **认证**：自定义实现，密码使用 `SHA-256(password + 'pet-paradise-salt')`；不依赖 Supabase Auth

---

## 七、默认账号

| 角色 | 用户名 | 密码 |
|---|---|---|
| 教师 | `teacher` | `teacher123` |

学生账号通过教师端"新增学生"或注册页创建。

---

## 八、部署到 Cloudflare Pages（可选）

仓库已自带 [`wrangler.jsonc`](./wrangler.jsonc) 与 [`.github/workflows/deploy.yml`](./.github/workflows/deploy.yml)。配置 GitHub Secrets：
- `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARE_ACCOUNT_ID`
- `VITE_SUPABASE_URL` / `VITE_SUPABASE_ANON_KEY`

push 到 main 分支即自动构建并发布。
