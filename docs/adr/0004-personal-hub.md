# ADR-0004 个人多设备协同（up-hub）

- 状态：已接受
- 日期：2026-10-18
- 依据：ADR-0001 第 20 条；用户需求："不做面向大范围用户的公共服务；用户个人有电脑和手机时，可以手机采样、电脑编曲并管理所有曲目"
- 实现：`runtime/up-hub`；协议细节见 `docs/API.md` 第 4 节

## 背景

用户选了三项：① 桌面端兼任个人 Hub + 局域网自动发现；② 设备间 P2P 直连（无中心）；③ 实时联动，手机当电脑的打击垫控制器。
参与的设备只有同一个人的几台设备，规模是"个位数设备 + 一个曲库"。不需要账号、云端或多租户，但局域网本身不可信（公共 Wi-Fi、宿舍网），必须防窃听、防冒充、防重放。

## 决策

### 1. 拓扑：任何设备都能当 Hub，桌面默认当 Hub

`HubServer` 与 `HubClient` 都在 up-hub 中，没有平台限制。桌面启动 Hub，手机作为客户端发现、配对、同步、当控制器。同步由客户端驱动（拉清单 → 双向传 blob → 推清单），Hub 只做存储与合并，因此不需要"中心"，两台设备直接连接即可。

### 2. 发现：mDNS / DNS-SD（`mdns-sd` crate）

服务 `_ultrapads._tcp.local.`，TXT 包含 `v`、`id`、`name`、`port`。选 `mdns-sd` 是因为它是纯 Rust 实现、不依赖异步运行时，并且能在 Android 交叉编译。TXT 中的 `id` 只作提示，身份在 TLS 握手时校验。发现失败（例如没有组播）时，仍可用 `HubClient::probe(ip:port)` 直连（手动输入 IP 或扫描二维码）。

### 3. 身份：每台设备一对 Ed25519 密钥

设备 ID 就是公钥，私钥种子以 0600 权限存入数据目录。不设 CA，也不签发证书链。同一进程内的 Hub 与 Client 如果使用同一个数据目录，会共享同一身份和同一份受信列表。

### 4. 鉴权：按公钥钉扎的双向 TLS 1.3（不用 bearer token，也不做逐请求签名）

候选方案比较：

| 方案 | 问题 |
|---|---|
| 配对后发放 bearer token，HTTP 明文 | 局域网嗅探即可盗用 token，曲库内容明文传输 |
| 每个请求用 Ed25519 签名 | 只能证明请求来源，响应仍可被篡改；没有加密；还要自己实现防重放和 body 摘要 |
| **双向 TLS 1.3 + 公钥钉扎**（采用） | 用成熟实现一次解决加密、完整性、双向认证与防重放；身份就是设备公钥，应用层只需查受信列表 |

具体做法：证书由设备 Ed25519 私钥自签（rcgen），自定义 rustls 校验器只看证书里的公钥。客户端只接受预期 Hub ID 的公钥；Hub 接受任意 Ed25519 客户端证书，再按受信列表授权。未配对设备只能访问 `/v1/info` 和 `/v1/pair/*`。撤销设备后立即生效，因为受信列表在每个请求上检查。

**密码学后端只用 ring**：`rustls`、`tokio-rustls`、`rcgen` 都关闭默认特性并启用 `ring`，不引入 `aws-lc-rs`（它在 Android 上需要 cmake 与额外工具链）。也没有使用 reqwest：reqwest 0.13 的 rustls 特性会带入 `rustls-platform-verifier`，它在 Android 上需要 JNI 初始化。客户端改为直接使用 hyper 1 + tokio-rustls，并自带一个小连接池。

### 5. 配对：6 位一次性码 + SPAKE2 + 绑定 TLS 公钥的确认 MAC

6 位码只有约 20 bit 熵。如果直接发送配对码或 `HMAC(code, …)`，主动中间人就能离线穷举。因此使用 SPAKE2（PAKE），并让确认 MAC 覆盖双方 TLS 证书中的公钥：

- 中间人即使替换了 TLS 公钥，不知道配对码也无法让两侧确认通过；每次尝试只是一次概率 1/10⁶ 的**在线**猜测；
- 配对码默认 5 分钟过期，最多 5 次尝试，成功一次即作废，生成新码时作废旧码和进行中的配对；
- 手机先校验 Hub 的确认值，所以输错配对码时手机端立即失败，不会把信任写入任何一方。

### 6. 同步：内容寻址 blob + 版本向量清单

- blob 以 BLAKE3 寻址，写入时流式计算哈希，提交前校验，不符即丢弃。中断后保留 `partial` 数据，下载用 `Range: bytes=N-`、上传用 `x-up-offset` 续传，续传时会先重新计算已有前缀的哈希；
- 条目带版本向量：单边修改不算冲突；并发修改按 LWW 取胜者，败者以确定性 ID 保留为冲突副本（`conflict_of` 标记），删除墓碑失败时不保留副本。合并满足交换律和幂等，所以两端各自合并后结果一致，重复同步也不会产生新的冲突；
- 不变量："清单不引用缺失的 blob"。Hub 在合并前检查引用的 blob 是否齐全，缺失时返回 `409 missing_blobs`；客户端在 blob 全部就位后才写本地清单。因此任何一步中断都可以安全重跑。

### 7. 控制器：UDP + 会话 HMAC（不用"配对时协商的会话 id"）

- `/v1/controller/open` 通过已认证的 TLS 下发 32 字节随机会话密钥。UDP 报文使用 `HMAC-SHA256` 截断到 16 字节的认证标签，在 LAN 上开销约 1 µs；
- 只在配对时协商一个会话 id 不够：它在 UDP 上明文出现，可被嗅探后伪造。会话密钥则不出现在报文中，而且每次连接更换；
- 每个事件连发 2 次。接收端用 1024 位滑动窗口去重并防重放，再做按 pad 的乱序处理（同一 pad 上的过期事件作废，避免挂音）；
- 会话结束（主动关闭、空闲 10 s、撤销、Hub 停止）时补发 `pad_up`，保证不挂音；
- 延迟通过 Ping/Pong 测量 RTT，单程估计 = RTT 中位数 / 2。本机实测（同一台机器，尚未跨设备）：回环约 0.1 ms，经本机 WLAN 地址约 0.24 ms。跨设备的 Wi-Fi 实测待 Android 端接入后补充到 `docs/research/`。
- 选 UDP 而不是 TCP/WebSocket，是为了避免队头阻塞：丢一个包只会丢一个事件，而双发已经把这种丢失的概率降到很低。WebSocket 回退尚未实现（见"后续"）。

### 8. 解耦：up-hub 不依赖 up-engine / up-library

- `LibraryStore`：列出、读取、写入 blob（流式，带续传）以及读写和原子合并清单。由 up-library 实现；`FsLibraryStore` 是基于文件系统的参考实现，可直接复用；
- `PadSink`：接收 `pad_down/pad_up/stop_all`，由主代理在 up-ffi 中接到引擎。它在 Hub 的 UDP 任务上同步调用，同一会话内保证有序，必须非阻塞；
- `HubTransport`：给控制面提供可靠字节流，给控制器提供不可靠数据报。v0.0.1 只实现 `LanTransport`（TCP + UDP）。

### 9. P2P（iroh）：只预留接口，v0.0.1 不实现

iroh 依赖较重（QUIC、relay、pkarr 等）。v0.0.1 的场景都在同一局域网内，因此暂不引入 iroh。后续接入方式：

1. 用设备 Ed25519 私钥作为 iroh `SecretKey`，这样 `NodeId` 就等于设备 ID，受信列表不用改；
2. `PeerAddr` 增加 `Iroh { node_id, relay_url, direct_addrs }` 变体（该枚举已标记 `#[non_exhaustive]`）；
3. 实现 `IrohTransport`：`connect_stream` 返回 QUIC 双向流，`connect_datagram` 使用 QUIC datagram，报文格式不变；
4. Hub 增加一个 iroh accept 循环，把双向流交给与 TCP 相同的 `serve_connection`。TLS 可以先保留（双层加密，实现最简单），之后再优化为直接信任 QUIC 的 NodeId 认证。

## Android 端集成要求（Kotlin 侧，由 app 实现）

up-hub 的 Rust 代码在 Android 上可以直接编译（已验证 `cargo ndk -t arm64-v8a/armeabi-v7a/x86_64`）。但 Android 默认会过滤 Wi-Fi 组播，mDNS 发现和广播需要应用做以下配合：

1. `AndroidManifest.xml` 声明权限：
   - `android.permission.INTERNET`
   - `android.permission.ACCESS_NETWORK_STATE`
   - `android.permission.ACCESS_WIFI_STATE`
   - `android.permission.CHANGE_WIFI_MULTICAST_STATE`（获取 MulticastLock 必需；属普通权限，无需运行时申请）
2. **获取组播锁的时机**：在调用 `hub_discover()` 或以 `advertise=true` 调用 `hub_start_server()`**之前**获取：
   ```kotlin
   val wifi = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
   val lock = wifi.createMulticastLock("ultrapads-mdns").apply { setReferenceCounted(true); acquire() }
   ```
   在停止发现、停止 Hub 或 App 进入后台时调用 `lock.release()`。持锁会增加耗电，不要常驻。
3. 发现得到的地址可能包含多个 IPv4 地址，客户端按顺序尝试，IPv4 优先、回环地址最后。部分路由器开启了"AP 隔离"，会屏蔽设备间的组播和单播，这时 UI 应提示用户手动输入 IP，或扫描桌面显示的二维码（内容为 `ip:port` + 设备 ID），然后走 `probe`。
4. 控制器 UDP 和控制面 TLS 都是 Rust 自己建立的原生 socket，不受 `network_security_config`（cleartext 策略）影响。
5. 手机作为控制器时，App 应保持前台，或使用前台服务，避免 Doze 模式下 UDP 被延迟。

## 后果

- 优点：无账号、无云端；局域网传输全程加密且双向认证；同步可以续传，结果确定，不会因为单边修改误报冲突；控制器延迟在亚毫秒级，并且有防挂音保证。
- 代价：首次配对需要用户输入 6 位码；设备换机或重装后身份会变化，需要重新配对；清单冲突的解决 UI 需要曲库或 App 实现（标记已经提供）。
- 限制：v0.0.1 只支持局域网；没有 WebSocket 回退；没有 blob 垃圾回收；Hub 不主动推送变更（客户端轮询或用户手动触发同步）。

## 后续（TODO）

1. iroh `HubTransport`（跨网段 / 蜂窝网络直连）
2. 控制器的 WebSocket（或 TCP）回退，用于 UDP 被防火墙拦截的情况
3. 清单变更推送（长轮询或 SSE），桌面变更后自动通知手机
4. 无引用 blob 的垃圾回收，以及按条目选择性同步（手机只拉部分曲目）
5. 二维码配对：内容含设备 ID 与地址，可以跳过 mDNS
6. 用 Hub 时钟同步（NTP 式偏移估计）让控制器事件带时间戳，以便在桌面工程中做抖动补偿和精确录制
