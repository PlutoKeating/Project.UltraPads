# ADR-0005：官方曲库目录与账号

状态：采纳（v0.3.0）

## 背景

官方曲目太少。需要大量可合法使用的素材，让用户直接做单曲即兴重排；同时需要账号来同步收藏与最近使用。项目是 Apache-2.0 代码 + 学习研究定位，素材许可证来源复杂（CC0 / CC BY / CC BY-SA / CC BY-NC）。

## 决策

1. **素材与代码分离。** 素材不进 Git；以 `.upkit`（内含 FLAC）存放在数据服务，经 Worker 透传分发。每个条目带许可证 ID、作者署名、来源链接，随 Kit 元数据一起写入包内。
2. **四类来源**：现成开放分轨（`album`，如 AlbumDB CC BY 4.0）、在线曲库（`online`，如 ccMixter 按条目许可证）、MIDI + 开源音色库渲染的原创素材（`synth`，CC0）、用户导入后本地分轨（`ugc`，后续期）。
3. **Kit 形态**：一首歌一个 Kit，按乐器分音色组，每组 12 个 pad，pad 放按小节或半小节切好的循环与完整元素（八拍、半八拍、完整节奏），默认按小节量化，开箱即可玩。
4. **许可证底线**：CC0、CC BY、CC BY-SA、CC BY-NC 都收，逐条标注。NC 条目使整体保持非商用定位；SA 条目的衍生 Kit 沿用同样许可证。导出录音若用了需署名的素材，在 WAV `bext` 元数据与分享文案里附署名。
5. **分发**：官网 Worker 提供目录 API，应用内按需下载；服务端存 FLAC，客户端入库时转 WAV（沿用 `up-library` 导入）。
6. **账号**：沿用 PlutoKeating 账号（`id.plutokeating.beer`，Ory Hydra）。App 客户端 `ultrapads-app`，授权码 + PKCE，使用 `flutter_appauth`。目录与下载匿名可用，登录后解锁云端收藏、最近使用、下载记录；日后的 UGC 上传也要求登录。
7. **后端**：延续 SayIt / J-nify 的模式——Cloudflare Worker（扩展现有 `website/worker`）只做验签、路由与透传，不处理字节；数据放深圳 ECS 上的 `ultrapads-data` 容器（SQLite + 本地文件），只对 Worker 开放。Worker 每请求 CPU 仅 10 ms，禁止在 Worker 里哈希或切分文件内容，完整性由 `sha256` 元数据让客户端核对。
8. **入库管线**：`tools/catalog` 脚本批处理（拉取、许可证校验、BPM / 小节对齐、切片、打包 `.upkit`、上传），发布前人工抽检；管线只写 `draft`，人工确认后改 `published`。
9. **后续期**：本地分轨（`Separator` trait，先 Demucs ONNX）与 UGC 公开分享（上传时声明来源与许可证，默认私有，支持举报下架）不在 v0.3.0 内。Demucs 预训练权重的授权存在争议，保持可插拔。

## 后果

- 新增运维面：`ultrapads-data` 容器、Kaiming 的 `ultrapads-app` 客户端、隧道的一条路径规则。运维细节记在对应私有仓库，不进本仓库。
- NC / SA 素材需要在 UI 与导出处给出提示，管线必须在入库时校验许可证。
- 目录内容随时可增删，不需要发版。
