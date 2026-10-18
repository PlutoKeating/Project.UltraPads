// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'up_l10n.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class UpL10nZh extends UpL10n {
  UpL10nZh([String locale = 'zh']) : super(locale);

  @override
  String get localeNativeName => '简体中文';

  @override
  String get localeEnglishName => 'Chinese (Simplified)';

  @override
  String get commonOk => '确定';

  @override
  String get commonCancel => '取消';

  @override
  String get commonDone => '完成';

  @override
  String get commonSave => '保存';

  @override
  String get commonDelete => '删除';

  @override
  String get commonEdit => '编辑';

  @override
  String get commonRename => '重命名';

  @override
  String get commonClose => '关闭';

  @override
  String get commonBack => '返回';

  @override
  String get commonNext => '下一步';

  @override
  String get commonSkip => '跳过';

  @override
  String get commonRetry => '重试';

  @override
  String get commonConfirm => '确认';

  @override
  String get commonApply => '应用';

  @override
  String get commonReset => '重置';

  @override
  String get commonSearch => '搜索';

  @override
  String get commonSeeMore => '查看更多';

  @override
  String get commonShare => '分享';

  @override
  String get commonPlay => '播放';

  @override
  String get commonPause => '暂停';

  @override
  String get commonStop => '停止';

  @override
  String get commonLoading => '加载中…';

  @override
  String get commonOn => '开';

  @override
  String get commonOff => '关';

  @override
  String get commonYes => '是';

  @override
  String get commonNo => '否';

  @override
  String get commonUndo => '撤销';

  @override
  String get commonRedo => '重做';

  @override
  String get commonCopy => '复制';

  @override
  String get commonPaste => '粘贴';

  @override
  String get commonImport => '导入';

  @override
  String get commonExport => '导出';

  @override
  String get commonAdd => '添加';

  @override
  String get commonRemove => '移除';

  @override
  String get commonDownload => '下载';

  @override
  String commonDownloadProgress(int percent) {
    return '下载中… $percent%';
  }

  @override
  String get commonUnknown => '未知';

  @override
  String get commonNew => '新';

  @override
  String get commonTop => '热门';

  @override
  String get commonAll => '全部';

  @override
  String get commonSelect => '选择';

  @override
  String get commonGotIt => '知道了';

  @override
  String get commonLearnMore => '了解更多';

  @override
  String get commonComingSoon => '敬请期待';

  @override
  String get commonNone => '无';

  @override
  String get navPerform => '演奏';

  @override
  String get navLibrary => '曲库';

  @override
  String get navCreate => '创作';

  @override
  String get navRecordings => '作品';

  @override
  String get navSettings => '设置';

  @override
  String get navMenu => '菜单';

  @override
  String get navSongs => '歌曲';

  @override
  String get navKits => '音色包';

  @override
  String get navProfile => '我的';

  @override
  String get performTutorial => '教程';

  @override
  String get performMoreOptions => '更多选项';

  @override
  String get performBankA => 'A';

  @override
  String get performBankB => 'B';

  @override
  String performSwitchBank(String bank) {
    return '切换到 $bank 组';
  }

  @override
  String get performStopAll => '全部停止';

  @override
  String performSpeed(double value) {
    final intl.NumberFormat valueNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String valueString = valueNumberFormat.format(value);

    return '速度 $valueString×';
  }

  @override
  String get performRecord => '录音';

  @override
  String get performRecording => '录音中…';

  @override
  String get performStopRecording => '停止录音';

  @override
  String get performEditKit => '编辑音色包';

  @override
  String get performShareKit => '分享音色包';

  @override
  String get performSkins => '皮肤';

  @override
  String get performVideoTutorial => '视频教程';

  @override
  String get performKitLoaded => '音色包已加载！';

  @override
  String performLoadingKit(String kitName) {
    return '正在加载 $kitName…';
  }

  @override
  String get performNoKit => '尚未加载音色包';

  @override
  String get performPickKit => '选择一个音色包';

  @override
  String get performPadEmpty => '空 Pad';

  @override
  String get performPadModeLoop => '循环';

  @override
  String get performPadModeOneShot => '单次';

  @override
  String get performPadModeGate => '按住';

  @override
  String performPadLabel(int number) {
    return 'Pad $number';
  }

  @override
  String performPadSemantics(int number, String mode, String state) {
    return 'Pad $number，$mode，$state';
  }

  @override
  String get performPadStatePlaying => '播放中';

  @override
  String get performPadStateIdle => '空闲';

  @override
  String get performPadStatePending => '等待下一小节';

  @override
  String get performQuantize => '量化';

  @override
  String get performQuantizeBar => '1 小节';

  @override
  String get performQuantizeBeat => '1 拍';

  @override
  String get performQuantizeOff => '关闭';

  @override
  String performTempo(int bpm) {
    return '$bpm BPM';
  }

  @override
  String get performMetronome => '节拍器';

  @override
  String get performKeyboardHint => '可以用键盘演奏 Pad';

  @override
  String get performMidiLearn => 'MIDI 学习';

  @override
  String get performControllerMode => '控制器模式';

  @override
  String get performInspiredBy => '灵感来自';

  @override
  String get libraryTitle => '音色包';

  @override
  String get librarySearchHint => '搜索歌曲、艺人或音色包';

  @override
  String get libraryFeatured => '精选';

  @override
  String get libraryNewSongs => '新歌';

  @override
  String get libraryTopSongs => '热门歌曲';

  @override
  String get libraryGenre => '曲风';

  @override
  String get libraryGenreHipHop => '嘻哈';

  @override
  String get libraryGenreFunkBr => '巴西放克';

  @override
  String get libraryGenreKpop => 'K-Pop';

  @override
  String get libraryGenreRock => '摇滚';

  @override
  String get libraryGenreDisco => '迪斯科';

  @override
  String get libraryGenreEdm => '电子舞曲';

  @override
  String get libraryGenrePop => '流行';

  @override
  String get libraryGenreTrap => '陷阱';

  @override
  String get libraryGenreHouse => '浩室';

  @override
  String get libraryGenreLatin => '拉丁';

  @override
  String get libraryKitBadge => '音色包';

  @override
  String libraryKitGenre(String genre) {
    return '$genre音乐';
  }

  @override
  String libraryInspiredBy(String artist) {
    return '灵感来自 $artist';
  }

  @override
  String get libraryLetsPlay => '开始演奏';

  @override
  String get libraryDownloadKit => '下载音色包';

  @override
  String get libraryDownloaded => '已下载';

  @override
  String get libraryNotDownloaded => '未下载';

  @override
  String libraryKitCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个音色包',
      zero: '暂无音色包',
    );
    return '$_temp0';
  }

  @override
  String libraryNoResults(String query) {
    return '没有找到“$query”的结果';
  }

  @override
  String get libraryEmpty => '曲库是空的。导入一个音色包开始吧。';

  @override
  String get libraryImportKit => '导入音色包';

  @override
  String get libraryImportFromFile => '从文件导入';

  @override
  String get libraryImportFromDevices => '从我的设备导入';

  @override
  String get libraryImportLinkHint => '粘贴音色包链接';

  @override
  String get libraryMyKits => '我的音色包';

  @override
  String get libraryFavorites => '收藏';

  @override
  String get libraryAddFavorite => '加入收藏';

  @override
  String get libraryRemoveFavorite => '取消收藏';

  @override
  String get libraryRecentlyPlayed => '最近演奏';

  @override
  String libraryNewKitAvailable(String kitName) {
    return '新音色包：$kitName';
  }

  @override
  String get librarySortBy => '排序';

  @override
  String get librarySortName => '名称';

  @override
  String get librarySortRecent => '最近';

  @override
  String get libraryDeleteKitTitle => '删除音色包？';

  @override
  String libraryDeleteKitBody(String kitName) {
    return '“$kitName”及其声音将从本设备中删除。';
  }

  @override
  String get kitEditorTitle => '编辑音色包';

  @override
  String get kitEditorNewKit => '新建音色包';

  @override
  String get kitEditorKitName => '音色包名称';

  @override
  String get kitEditorKitNameHint => '我的音色包';

  @override
  String get kitEditorDescription => '简介';

  @override
  String get kitEditorColor => '颜色';

  @override
  String get kitEditorPadColor => 'Pad 颜色';

  @override
  String get kitEditorPadMode => 'Pad 模式';

  @override
  String get kitEditorChokeGroup => '互斥组';

  @override
  String kitEditorChokeGroupValue(int group) {
    return '第 $group 组';
  }

  @override
  String get kitEditorPitch => '音高';

  @override
  String kitEditorPitchValue(String semitones) {
    return '$semitones 半音';
  }

  @override
  String get kitEditorTimeStretch => '变速';

  @override
  String get kitEditorVolume => '音量';

  @override
  String get kitEditorPan => '声像';

  @override
  String get kitEditorTrim => '裁剪';

  @override
  String get kitEditorFadeIn => '淡入';

  @override
  String get kitEditorFadeOut => '淡出';

  @override
  String get kitEditorPreview => '试听';

  @override
  String get kitEditorClearPad => '清空 Pad';

  @override
  String get kitEditorCopyPad => '复制 Pad';

  @override
  String get kitEditorPastePad => '粘贴 Pad';

  @override
  String get kitEditorSaveKit => '保存音色包';

  @override
  String get kitEditorSaved => '音色包已保存';

  @override
  String get kitEditorUnsavedTitle => '放弃修改？';

  @override
  String get kitEditorUnsavedBody => '这个音色包有尚未保存的修改。';

  @override
  String get kitEditorDiscard => '放弃';

  @override
  String get kitEditorSelectPad => '选择一个 Pad 来载入声音';

  @override
  String kitEditorMaxLength(int seconds) {
    return '声音长度不能超过 $seconds 秒';
  }

  @override
  String get loadSoundTitle => '载入声音';

  @override
  String get loadSoundImportFrom => '导入自';

  @override
  String get loadSoundRecordingFrom => '录制自';

  @override
  String get loadSoundSourceSongs => '内置歌曲';

  @override
  String get loadSoundSourceMicrophone => '麦克风';

  @override
  String get loadSoundSourceFiles => '本地文件';

  @override
  String get loadSoundSourceKits => '其他音色包';

  @override
  String get loadSoundSourceRecordings => '录音作品';

  @override
  String get loadSoundHoldToRecord => '按住录音';

  @override
  String loadSoundElapsed(int seconds) {
    return '$seconds 秒';
  }

  @override
  String get recordStart => '开始录音';

  @override
  String get recordStop => '停止录音';

  @override
  String get recordSaveTitle => '保存录音';

  @override
  String get recordNameHint => '录音名称';

  @override
  String recordDefaultName(int number) {
    return '音轨 $number';
  }

  @override
  String get recordSaved => '录音已保存';

  @override
  String get recordDiscardTitle => '放弃这段录音？';

  @override
  String get worksTitle => '我的作品';

  @override
  String get worksEmpty => '还没有作品。点击录音按钮录下你的第一首音轨。';

  @override
  String worksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个作品',
      zero: '暂无作品',
    );
    return '$_temp0';
  }

  @override
  String worksRecordedOn(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return '录制于 $dateString';
  }

  @override
  String get worksExportWav => '导出 WAV';

  @override
  String get worksLoop => '循环播放';

  @override
  String get worksShuffle => '随机播放';

  @override
  String get worksDeleteTitle => '删除作品？';

  @override
  String worksDeleteBody(String name) {
    return '“$name”将被永久删除。';
  }

  @override
  String get worksRenameTitle => '重命名作品';

  @override
  String get tutorialTitle => '教程';

  @override
  String tutorialStep(int current, int total) {
    return '第 $current/$total 步';
  }

  @override
  String get tutorialTapHighlighted => '点击高亮的 Pad';

  @override
  String tutorialSwitchBank(String bank) {
    return '切换到 $bank 组';
  }

  @override
  String get tutorialComplete => '太棒了！教程完成';

  @override
  String get tutorialRestart => '重新开始';

  @override
  String get tutorialExit => '退出教程';

  @override
  String tutorialProgress(int percent) {
    return '已完成 $percent%';
  }

  @override
  String get tutorialUnavailable => '这个音色包还没有教程';

  @override
  String get tutorialWatchVideo => '观看视频';

  @override
  String get skinTitle => '皮肤';

  @override
  String get skinNeon => '霓虹';

  @override
  String get skinOutline => '描边';

  @override
  String get skinLight => '浅色';

  @override
  String get skinCustom => '自定义';

  @override
  String get skinApply => '应用皮肤';

  @override
  String get skinApplied => '已应用皮肤';

  @override
  String get skinEditorTitle => '皮肤编辑器';

  @override
  String get skinEditorNew => '新建皮肤';

  @override
  String skinEditorBasedOn(String skin) {
    return '基于$skin';
  }

  @override
  String get skinEditorNameHint => '皮肤名称';

  @override
  String get skinEditorGroupSurface => '背景';

  @override
  String get skinEditorGroupText => '文字';

  @override
  String get skinEditorGroupAccent => '强调色';

  @override
  String get skinEditorGroupPad => 'Pad';

  @override
  String get skinEditorGroupPalette => 'Pad 色板';

  @override
  String skinEditorPaletteRole(int index) {
    return '颜色 $index';
  }

  @override
  String get skinEditorCore => '中心';

  @override
  String get skinEditorMid => '中间';

  @override
  String get skinEditorEdge => '边缘';

  @override
  String get skinEditorGlow => '光晕';

  @override
  String get skinEditorCornerRadius => '圆角';

  @override
  String get skinEditorGlowIntensity => '光晕强度';

  @override
  String get skinEditorResetToken => '恢复默认';

  @override
  String get skinEditorResetAll => '全部恢复';

  @override
  String get skinEditorExport => '导出皮肤';

  @override
  String get skinEditorImport => '导入皮肤';

  @override
  String get skinEditorImportInvalid => '皮肤文件无效';

  @override
  String skinEditorImportIgnored(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已忽略 $count 项来自新版本的设置',
    );
    return '$_temp0';
  }

  @override
  String skinEditorChangeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 处修改',
      zero: '没有修改',
    );
    return '$_temp0';
  }

  @override
  String get skinEditorDeleteTitle => '删除皮肤？';

  @override
  String get skinPresetDefault => '默认';

  @override
  String get skinPresetNumber => '数字';

  @override
  String get skinPresetChristmas => '圣诞';

  @override
  String get skinPresetPets => '萌宠';

  @override
  String get skinPresetCover => '封面';

  @override
  String get skinPresetBroken => '裂纹';

  @override
  String get skinPresetMuertos => '亡灵节';

  @override
  String get skinPresetCrazy => '疯狂';

  @override
  String get skinPresetLaunchpad => '发射台';

  @override
  String get skinPresetCrafts => '手工';

  @override
  String get skinPresetPolished => '亮面';

  @override
  String get skinPresetClean => '简洁';

  @override
  String get skinPresetCircle => '圆形';

  @override
  String get skinPresetSquare => '方块';

  @override
  String get skinPresetLgbt => '彩虹';

  @override
  String get skinPresetHalloween => '万圣节';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsAudio => '音频';

  @override
  String get settingsOutputDevice => '输出设备';

  @override
  String get settingsInputDevice => '输入设备';

  @override
  String get settingsBufferSize => '缓冲大小';

  @override
  String settingsBufferSizeValue(int frames, double ms) {
    final intl.NumberFormat msNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String msString = msNumberFormat.format(ms);

    return '$frames 采样（$msString 毫秒）';
  }

  @override
  String get settingsSampleRate => '采样率';

  @override
  String settingsSampleRateValue(int rate) {
    return '$rate Hz';
  }

  @override
  String get settingsLatency => '延迟';

  @override
  String get settingsMeasureLatency => '测量延迟';

  @override
  String settingsLatencyValue(int ms) {
    return '$ms 毫秒';
  }

  @override
  String get settingsLanguage => '语言';

  @override
  String settingsLanguageSystem(String language) {
    return '跟随系统（$language）';
  }

  @override
  String get settingsAppearance => '外观';

  @override
  String get settingsSkin => '皮肤';

  @override
  String get settingsAnimatePads => 'Pad 动画';

  @override
  String get settingsReduceMotion => '减少动态效果';

  @override
  String get settingsHaptics => '触感反馈';

  @override
  String get settingsKeepScreenOn => '保持屏幕常亮';

  @override
  String get settingsMidi => 'MIDI';

  @override
  String get settingsMidiDevices => 'MIDI 设备';

  @override
  String get settingsMidiNone => '没有连接 MIDI 设备';

  @override
  String get settingsKeyboardMapping => '键盘映射';

  @override
  String get settingsStorage => '存储';

  @override
  String settingsStorageUsed(String size) {
    return '已使用 $size';
  }

  @override
  String get settingsClearCache => '清除缓存';

  @override
  String get settingsCacheCleared => '缓存已清除';

  @override
  String get settingsAbout => '关于';

  @override
  String settingsVersion(String version) {
    return '版本 $version';
  }

  @override
  String get settingsLicenses => '开源许可';

  @override
  String get settingsPrivacy => '隐私';

  @override
  String get settingsResearchNotice =>
      'UltraPads 是以学习研究为目的的开源项目（Apache-2.0）。';

  @override
  String get hubTitle => '我的设备';

  @override
  String get hubDescription => '通过局域网同步曲库，并把手机当作打击垫控制器。';

  @override
  String get hubEnable => '在本机运行 Hub';

  @override
  String hubRunning(String address) {
    return 'Hub 正在运行：$address';
  }

  @override
  String get hubStopped => 'Hub 已停止';

  @override
  String get hubDiscovering => '正在查找设备…';

  @override
  String get hubNoDevices => '在当前网络中没有发现设备';

  @override
  String get hubDeviceOnline => '在线';

  @override
  String get hubDeviceOffline => '离线';

  @override
  String hubDeviceLastSeen(String time) {
    return '最后在线 $time';
  }

  @override
  String hubDeviceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 台已配对设备',
      zero: '没有已配对设备',
    );
    return '$_temp0';
  }

  @override
  String get pairingNewDevice => '配对新设备';

  @override
  String get pairingCodeTitle => '配对码';

  @override
  String pairingCodeBody(String code) {
    return '请在另一台设备上输入此配对码：$code';
  }

  @override
  String get pairingEnterCode => '输入另一台设备上显示的配对码';

  @override
  String pairingConfirm(String deviceName) {
    return '与 $deviceName 配对？';
  }

  @override
  String pairingSuccess(String deviceName) {
    return '已与 $deviceName 配对';
  }

  @override
  String get pairingFailed => '配对失败，请检查配对码后重试。';

  @override
  String get pairingExpired => '配对码已过期';

  @override
  String get pairingUnpair => '取消配对';

  @override
  String pairingUnpairConfirm(String deviceName) {
    return '取消与 $deviceName 的配对？它将不再与本机同步。';
  }

  @override
  String get pairingOwnDevicesOnly => '请只配对你自己的设备。';

  @override
  String get pairingSameNetwork => '两台设备需要连接同一个 Wi-Fi 网络。';

  @override
  String get hubSyncLibrary => '同步曲库';

  @override
  String hubSyncProgress(int done, int total) {
    return '正在同步 $done/$total…';
  }

  @override
  String get hubSyncDone => '曲库已是最新';

  @override
  String hubSyncConflicts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '有 $count 处冲突需要处理',
    );
    return '$_temp0';
  }

  @override
  String get hubUseAsController => '用作控制器';

  @override
  String hubControlling(String deviceName) {
    return '正在控制 $deviceName';
  }

  @override
  String hubDisconnected(String deviceName) {
    return '已与 $deviceName 断开';
  }

  @override
  String hubRoundTrip(int ms) {
    return '往返 $ms 毫秒';
  }

  @override
  String get errorGeneric => '出了点问题';

  @override
  String get errorNetwork => '没有网络连接';

  @override
  String get errorTimeout => '请求超时';

  @override
  String get errorDownloadFailed => '下载失败，请检查网络后重试。';

  @override
  String get errorKitCorrupt => '音色包已损坏，无法加载';

  @override
  String get errorKitNotFound => '找不到音色包';

  @override
  String get errorAudioDevice => '音频设备不可用';

  @override
  String errorAudioEngine(String code) {
    return '无法启动音频引擎（$code）';
  }

  @override
  String get errorStorageFull => '存储空间不足';

  @override
  String errorFileRead(String fileName) {
    return '无法读取“$fileName”';
  }

  @override
  String errorFileWrite(String fileName) {
    return '无法保存“$fileName”';
  }

  @override
  String get errorUnsupportedFormat => '不支持这种文件格式';

  @override
  String get errorRecordingFailed => '录音失败';

  @override
  String get errorPermissionDenied => '权限被拒绝';

  @override
  String errorDeviceUnreachable(String deviceName) {
    return '无法连接 $deviceName';
  }

  @override
  String errorVersionMismatch(String deviceName) {
    return '$deviceName 的版本不兼容';
  }

  @override
  String get errorNameEmpty => '名称不能为空';

  @override
  String errorNameTooLong(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '名称不能超过 $max 个字符',
    );
    return '$_temp0';
  }

  @override
  String get errorNameTaken => '名称已被使用';

  @override
  String get permissionMicrophoneTitle => '麦克风权限';

  @override
  String get permissionMicrophoneBody =>
      'UltraPads 需要使用麦克风把声音录进 Pad。录音只保存在你的设备上。';

  @override
  String get permissionStorageTitle => '文件访问权限';

  @override
  String get permissionStorageBody => '允许访问文件，以便导入音频和导出作品。';

  @override
  String get permissionLocalNetworkTitle => '本地网络';

  @override
  String get permissionLocalNetworkBody => '仅用于在当前 Wi-Fi 中发现并连接你自己的设备。';

  @override
  String get permissionBluetoothTitle => '蓝牙 MIDI';

  @override
  String get permissionBluetoothBody => '允许使用蓝牙以连接无线 MIDI 控制器。';

  @override
  String get permissionNotificationsTitle => '通知';

  @override
  String get permissionNotificationsBody => '在同步或导出完成时通知你。';

  @override
  String get permissionAllow => '允许';

  @override
  String get permissionOpenSettings => '前往设置';

  @override
  String get permissionDeniedForever => '权限已被拒绝，可以在系统设置中开启。';

  @override
  String shareKitMessage(String kitName) {
    return '在 UltraPads 上演奏我的音色包“$kitName”';
  }

  @override
  String shareRecordingMessage(String name) {
    return '听听用 UltraPads 制作的“$name”';
  }

  @override
  String get shareLinkCopied => '链接已复制';

  @override
  String get a11yOpenMenu => '打开菜单';

  @override
  String get a11yCloseSheet => '关闭面板';

  @override
  String a11yKitCover(String kitName) {
    return '$kitName 的封面';
  }

  @override
  String a11yWaveform(String name) {
    return '$name 的波形';
  }

  @override
  String a11yProgress(int percent) {
    return '百分之 $percent';
  }

  @override
  String get timeJustNow => '刚刚';

  @override
  String timeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 分钟前',
    );
    return '$_temp0';
  }

  @override
  String timeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 小时前',
    );
    return '$_temp0';
  }

  @override
  String timeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 天前',
      one: '昨天',
    );
    return '$_temp0';
  }

  @override
  String unitSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 秒',
    );
    return '$_temp0';
  }

  @override
  String get onboardingMakeMusicTitle => '创作你自己的音乐！';

  @override
  String get onboardingRhythmsTitle => '享受最棒的节奏';

  @override
  String get onboardingLoopsTitle => '发现 DJ 循环与节拍！';

  @override
  String get onboardingStyleTitle => '选择你的风格';

  @override
  String get onboardingShareTitle => '分享你的音乐';

  @override
  String get onboardingStart => '开始';

  @override
  String onboardingPlayStyle(String choice) {
    String _temp0 = intl.Intl.selectLogic(choice, {
      'solo': '一个人玩',
      'jam': '和朋友一起',
      'other': '随便看看',
    });
    return '$_temp0';
  }

  @override
  String performSpeedValue(double value) {
    final intl.NumberFormat valueNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String valueString = valueNumberFormat.format(value);

    return '$valueString×';
  }

  @override
  String get settingsClassicPads => '经典 Pad 动画';

  @override
  String settingsEngineBackend(String name) {
    return '音频引擎：$name';
  }

  @override
  String get settingsEngineFallback => '原生音频引擎不可用，正在以演示模式运行';

  @override
  String get errorEngineUnsupported => '音频引擎暂不支持此功能';

  @override
  String get loadSoundPickSample => '选择声音';

  @override
  String get hubThisDevice => '本机';

  @override
  String get hubNearbyDevices => '附近的设备';

  @override
  String get settingsPrivateAssets => '原 App 素材';

  @override
  String get onboardingSkip => '跳过';

  @override
  String get performLearnToPlay => '学习演奏';

  @override
  String get performBackToTools => '返回';

  @override
  String get performSpeedNormal => '正常';

  @override
  String get performSpeedSlow => '慢速';

  @override
  String get performSpeedVerySlow => '很慢';

  @override
  String get tutorialPerfect => '完美';

  @override
  String get tutorialTooFast => '太快了';

  @override
  String get tutorialTooSlow => '太慢了';

  @override
  String get tutorialMiss => '错过';

  @override
  String get tutorialPressWhenFull => '在 Pad 完全填满时按下';

  @override
  String get tutorialPlayDemo => '播放';

  @override
  String get navFeed => '推荐';

  @override
  String get librarySeeAll => '查看全部';

  @override
  String get libraryArtists => '艺人';

  @override
  String get libraryRecommended => '为你推荐';

  @override
  String get libraryOpenKit => '打开 Kit';

  @override
  String get kitEditorEditPad => '编辑 Pad';

  @override
  String get kitEditorEditFile => '编辑音频';

  @override
  String get kitEditorClone => '复制';

  @override
  String get kitEditorGroup => '分组';

  @override
  String get kitEditorLoop => '循环';

  @override
  String get kitEditorReplaceTitle => '替换这个声音？';

  @override
  String get recordSaveAndShare => '保存并分享';

  @override
  String get onboardingNext => '下一步';

  @override
  String get onboardingChooseStyleBody => '选择你喜欢的风格，我们会为你推荐合适的 Kit';

  @override
  String get settingsDeveloper => '开发者';

  @override
  String get settingsDesignGallery => '设计画廊';

  @override
  String get settingsGalleryTokens => '设计 Token';

  @override
  String get settingsGalleryComponents => '组件';

  @override
  String get settingsGallerySkins => '主题与皮肤';

  @override
  String get settingsGalleryMotion => '动效';

  @override
  String get settingsGalleryPrimitive => '基础色';

  @override
  String get settingsGallerySemantic => '语义色';

  @override
  String get settingsGalleryRadii => '圆角';

  @override
  String get settingsGallerySpacing => '间距';

  @override
  String get settingsGalleryTypography => '字体角色';

  @override
  String get settingsGalleryGlow => '光晕与阴影';

  @override
  String get settingsGalleryDurations => '时长与曲线';

  @override
  String get settingsGalleryReplay => '重播';

  @override
  String get settingsGalleryStates => '状态';

  @override
  String get settingsGalleryDisabled => '禁用';

  @override
  String get settingsGalleryPressed => '按下';

  @override
  String get hubLocalAddresses => '本机地址';

  @override
  String get hubAddressHint => '手机没有自动发现本机时，在手机上手动输入下面任一地址。';

  @override
  String get pairingNewCode => '生成新配对码';

  @override
  String pairingValidUntil(String time) {
    return '$time 前有效，最多尝试 5 次';
  }

  @override
  String get hubTrustedDevices => '受信设备';

  @override
  String get hubRevoke => '撤销';

  @override
  String hubRevokeConfirm(String deviceName) {
    return '撤销对 $deviceName 的信任？它将不能再同步或控制本机。';
  }

  @override
  String hubRemoteControlling(String deviceName) {
    return '$deviceName 正在控制本机';
  }

  @override
  String get hubManualAddress => '手动输入地址';

  @override
  String get hubManualAddressHint => 'IP 或 IP:端口，例如 192.168.1.10:47100';

  @override
  String get hubConnect => '连接';

  @override
  String hubProbeFailed(String address) {
    return '无法连接 $address';
  }

  @override
  String get hubLocalEcho => '本机同时发声';

  @override
  String get hubLocalEchoHint => '默认只在被控制的设备上发声';

  @override
  String get hubStopControlling => '退出控制器模式';

  @override
  String hubSyncFinished(int down, int up) {
    return '同步完成：下载 $down 个、上传 $up 个文件';
  }

  @override
  String get hubSyncStarting => '正在准备同步…';

  @override
  String hubDeviceId(String id) {
    return '设备 ID：$id';
  }

  @override
  String hubErrorOp(String op) {
    return 'Hub 操作失败（$op）';
  }

  @override
  String get settingsAudioStatus => '音频状态';

  @override
  String settingsAudioStatusValue(
    String host,
    String device,
    int channels,
    String format,
  ) {
    return '$host · $device · $channels 声道 $format';
  }

  @override
  String get settingsAudioStopped => '音频输出未运行';

  @override
  String get performVideoPlatform => 'BiliBili';

  @override
  String get performVideoOpenFailed => '无法打开视频链接';

  @override
  String tutorialFirstGuideStep(int step, int total) {
    return '第 $step/$total 步';
  }

  @override
  String get tutorialFirstGuidePad => '按下 Pad，开始你的第一段节奏！';

  @override
  String get tutorialFirstGuideLearn => '点「学习演奏」，跟着教程一步步弹完整首歌。';

  @override
  String get tutorialFirstGuideMore => '⋮ 里有录音、皮肤、编辑 Kit 和设置。';

  @override
  String get tutorialFirstGuideSongs => '点 SONGS 打开曲库，挑选更多 Kit。';

  @override
  String get tutorialFirstGuideDone => '开始演奏';

  @override
  String get settingsReplayGuide => '重新显示新手引导';

  @override
  String get settingsReplayGuideDone => '回到演奏页即可看到引导';

  @override
  String get settingsBufferSizeSystem => '系统默认';
}
