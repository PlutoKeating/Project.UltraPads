# up_i18n

UltraPads 的独立 i18n 包。**页面里永远不写任何语言的字面文案**，一律通过 `UpL10n` 取用（由 `tools/lint/no_hardcode.dart` 检查）。

- ARB 源：`lib/l10n/app_<locale>.arb`（模板是 `app_en.arb`，元数据 `@key` 只写在模板里）
- 生成代码：`lib/src/generated/`（`flutter gen-l10n`，配置见 `l10n.yaml`；**入库**，不要手改）
- 运行时：`UpL10n`、`UpLocales`（解析和回退）、`LocaleController`（跟随系统或手动选择，持久化接口抽象为 `LocaleStore`）
- 工具：`bin/add_locale.dart`、`bin/check.dart`、`bin/gen.dart`（纯 Dart，逻辑在 `lib/src/tooling/arb_tools.dart`）

首期语言：`en`（模板、兜底）、`zh`（简体中文）。

## 接入

```dart
final locales = LocaleController(store: MyPrefsLocaleStore());   // 实现 LocaleStore 的 read/write
await locales.load();

ListenableBuilder(
  listenable: locales,
  builder: (context, _) => MaterialApp(
    locale: locales.locale,                                   // null = 跟随系统
    supportedLocales: UpL10n.supportedLocales,
    localizationsDelegates: UpL10n.localizationsDelegates,
    localeListResolutionCallback: UpLocales.resolutionCallback,
    home: const Home(),
  ),
);

// 页面里
final l10n = UpL10n.of(context);          // 或 context.l10n
Text(l10n.performTutorial);
Text(l10n.libraryKitCount(kits.length));  // ICU 复数
Text(l10n.worksRecordedOn(date));         // 日期占位符（按当前语言格式化）
Text(l10n.performSpeed(1.5));             // 数字占位符（保留 1 位小数）

// 设置页：语言选择
await locales.setLocale(const Locale('zh'));  // 手动
await locales.followSystem();                 // 跟随系统
UpLocales.lookup(locale).localeNativeName;    // 每种语言用自己的语言显示名称
```

回退顺序：完全匹配 → 同语言同 script → 同语言同地区 → 同语言 → `en`。例如 `zh_Hant_TW` 在只有 `zh` 时得到 `zh`；`fr` 得到 `en`。

## Key 命名规范

- lowerCamelCase、纯 ASCII，格式为 `<domain><Element>[<Qualifier>]`，例如 `performTutorial`、`kitEditorUnsavedTitle`、`errorFileRead`。
- 必须以下列 domain 之一开头（`bin/check.dart` 强制检查）：

| domain | 范围 |
|---|---|
| `locale` | 语言自身的名称（`localeNativeName`、`localeEnglishName`） |
| `common` | 通用按钮和状态（确定、取消、加载中…） |
| `nav` | 导航、Tab、顶栏入口 |
| `perform` | 演奏页（pad、A/B、传输栏、量化、录音按钮） |
| `library` | 曲库（Banner、搜索、Kit 卡片、曲风、下载、收藏） |
| `kitEditor` / `loadSound` | 编辑 Kit / LOAD SOUND 来源面板 |
| `record` / `works` | 录音 / 作品列表 |
| `tutorial` | 教程 |
| `skin` / `skinEditor` | 皮肤选择 / 自定义皮肤编辑器 |
| `settings` | 设置 |
| `hub` / `pairing` | 多设备协同 / 配对 |
| `error` | 错误提示 |
| `permission` | 权限说明 |
| `share`、`a11y`、`time`、`unit`、`onboarding` | 分享文案、读屏、相对时间、单位、引导页 |

- 弹窗用 `…Title` / `…Body` 成对命名；可点击的动作用动词（`libraryDownloadKit`）。
- **文案保存正常大小写**，全大写由排版角色决定（`UpTheme.of(context).text.format(UpTextRole.title, …)`）。不要在 ARB 里写 `SONGS`。
- 有占位符的消息必须在模板的 `@key.placeholders` 里声明类型；计数一律用 ICU `plural`，枚举用 `select`，不要拼接字符串。
- 给译者看的上下文写在 `@key.description`。

## 新增语言

```bash
dart run up_i18n:add_locale ja          # 也支持 pt-BR、zh-Hant 等写法；仓库根目录或包目录都能运行
```

脚本会：

1. 复制 `app_en.arb` → `app_ja.arb`（文案先用英文，加上 `"@@x-status": "pending-translation…"` 标记）
2. 运行 `flutter gen-l10n`，`UpL10n.supportedLocales` 自动加入 `ja`（`LocaleController` 和语言选择器都从这里读取支持列表，不需要改代码）
3. 打印剩余步骤：翻译 → `dart run up_i18n:check --strict` → iOS/macOS 在 `Info.plist` 的 `CFBundleLocalizations` 中加入语言代码

## 检查与生成

```bash
dart run up_i18n:check            # 缺失 key、多余 key、占位符不一致、key 命名 → 报错（退出码 1）
dart run up_i18n:check --strict   # 另外把"与英文相同（疑似未翻译）"的警告也当作错误
dart run up_i18n:gen              # 重新生成 + 检查（pubspec 中 generate: true，flutter pub get 也会触发生成）
```

`arbIdenticalAllowed`（`lib/src/tooling/arb_tools.dart`）列出允许与英文相同的 key（A/B、BPM、MIDI 等）。

## 测试

`flutter test`：仓库 ARB 的一致性、ICU 参数解析、add_locale 生成、缺失/多余/占位符漂移检测、locale 解析和回退、`LocaleController` 持久化、复数/select/数字/日期消息、`UpL10n.of` / `context.l10n`。
