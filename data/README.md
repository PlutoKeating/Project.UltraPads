# ultrapads-data

UltraPads 的数据服务：官方曲库目录、`.upkit` 文件存储，以及账号数据（收藏、最近使用、下载记录）。目录元数据与账号数据在 SQLite（WAL），`.upkit` 以内容寻址的方式存成本地文件。

技术栈：Node 24 + Hono + `node:sqlite`（内置），打包为只读根文件系统的安全加固 Docker 容器（非 root、丢弃全部 capability、内存 256 MB），只监听本机 `127.0.0.1:8791`，经反向隧道只对 Cloudflare Worker（`website/worker`）开放。客户端从不直连本服务。契约见 [`docs/API.md`](../docs/API.md) §7，决策见 [`docs/adr/0005-catalog-and-accounts.md`](../docs/adr/0005-catalog-and-accounts.md)。

## 接口

所有路径都可以带可选的 `/ultrapads` 前缀（共用隧道按路径分流，前缀由服务剥掉）。

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/health` | 健康检查（无需密钥） |
| GET | `/v1/catalog` | 已发布条目：`q`、`license`（可重复或逗号分隔）、`genre`、`origin`、`bpm_min`、`bpm_max`、`sort=new\|bpm\|title`、`cursor`、`limit`（≤ 50）→ `{ items, next_cursor, total }` |
| GET | `/v1/catalog/facets` | `{ licenses, genres, origins }`，每项 `{ id, count }` |
| GET | `/v1/catalog/:id` | 单个条目 |
| GET | `/v1/catalog/:id/file` | 流式返回 `.upkit`，支持 `Range`、`ETag`（= sha256）、`If-None-Match`，头 `X-Digest: sha256:<hex>` |
| GET | `/v1/users/:sub/state` | `{ favorites, recent, downloads }` |
| PUT / DELETE | `/v1/users/:sub/favorites/:id` | 收藏 / 取消（幂等，收藏必须引用已发布条目） |
| POST | `/v1/users/:sub/recent` · `/downloads` | `{ id }`；同一条目只保留最新一次，各保留最近 100 条 |
| DELETE | `/v1/users/:sub` | 级联删除该账号的全部数据 |
| GET | `/v1/admin/catalog[/:id[/file]]` | 运营：含草稿的列表、详情与文件 |
| PUT | `/v1/admin/catalog/:id` | 创建 / 更新元数据（`status: draft\|published`）。`license` 必须在白名单内，`commercial_ok` / `share_alike` 由服务按许可证计算；没有文件不能发布（`409 no_file`） |
| PUT | `/v1/admin/catalog/:id/file` | 流式上传 `.upkit`：写临时文件 → 计算 sha256 → 核对可选的 `x-sha256`（不符 `422`）→ 校验 ZIP 魔数 → 原子 rename 到 `files/<hh>/<sha256>`；同内容只存一份，被替换的旧文件无人引用时清理 |
| DELETE | `/v1/admin/catalog/:id` | 删除条目、所有人的相关记录，以及无人引用的文件 |

## 鉴权

- 普通接口：`Authorization: Bearer <ULTRAPADS_DATA_KEY>`。密钥只放在 Cloudflare Worker 的 Secret 里。
- `/v1/admin/*` 另需请求头 `X-Up-Admin: <ULTRAPADS_ADMIN_KEY>`。运营密钥只给目录管线使用，Worker 不持有。
- 两把密钥都至少 32 个字符且不能相同，比较一律用常量时间。

## 数据目录

```
<ULTRAPADS_DATA_DIR>/
├── ultrapads.sqlite      目录元数据与账号数据（WAL）
├── files/<hh>/<sha256>   内容寻址的 .upkit；files/.tmp 是上传中的临时文件
└── backups/              每日 VACUUM INTO 备份，保留最近 7 份
```

## 本地开发与测试

```bash
cd data
npm ci
npm run typecheck
npm test
npm run dev        # 127.0.0.1:8791，数据在 .dev/（不入库）
```

## 部署

```bash
cd data
./start.sh              # 首次自动生成 .env（权限 600）与两把 48 位随机密钥，构建并启动容器，等待健康检查通过
./start.sh --key        # 打印服务密钥，供配置 Worker Secret ULTRAPADS_DATA_KEY 使用
./start.sh --admin-key  # 打印运营密钥，供目录管线上传使用
```

环境变量见 `.env.example`；容器内固定监听 `8080`，由 `compose.yaml` 只发布到 `127.0.0.1:${ULTRAPADS_DATA_LOCAL_PORT:-8791}`。
