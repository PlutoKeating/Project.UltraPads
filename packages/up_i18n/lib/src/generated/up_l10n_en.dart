// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'up_l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class UpL10nEn extends UpL10n {
  UpL10nEn([String locale = 'en']) : super(locale);

  @override
  String get localeNativeName => 'English';

  @override
  String get localeEnglishName => 'English';

  @override
  String get commonOk => 'OK';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonDone => 'Done';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonRename => 'Rename';

  @override
  String get commonClose => 'Close';

  @override
  String get commonBack => 'Back';

  @override
  String get commonNext => 'Next';

  @override
  String get commonSkip => 'Skip';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonApply => 'Apply';

  @override
  String get commonReset => 'Reset';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonSeeMore => 'See more';

  @override
  String get commonShare => 'Share';

  @override
  String get commonPlay => 'Play';

  @override
  String get commonPause => 'Pause';

  @override
  String get commonStop => 'Stop';

  @override
  String get commonLoading => 'Loading…';

  @override
  String get commonOn => 'On';

  @override
  String get commonOff => 'Off';

  @override
  String get commonYes => 'Yes';

  @override
  String get commonNo => 'No';

  @override
  String get commonUndo => 'Undo';

  @override
  String get commonRedo => 'Redo';

  @override
  String get commonCopy => 'Copy';

  @override
  String get commonPaste => 'Paste';

  @override
  String get commonImport => 'Import';

  @override
  String get commonExport => 'Export';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonRemove => 'Remove';

  @override
  String get commonDownload => 'Download';

  @override
  String commonDownloadProgress(int percent) {
    return 'Downloading… $percent%';
  }

  @override
  String get commonUnknown => 'Unknown';

  @override
  String get commonNew => 'New';

  @override
  String get commonTop => 'Top';

  @override
  String get commonAll => 'All';

  @override
  String get commonSelect => 'Select';

  @override
  String get commonGotIt => 'Got it';

  @override
  String get commonLearnMore => 'Learn more';

  @override
  String get commonComingSoon => 'Coming soon';

  @override
  String get commonNone => 'None';

  @override
  String get navPerform => 'Perform';

  @override
  String get navLibrary => 'Library';

  @override
  String get navCreate => 'Create';

  @override
  String get navRecordings => 'Recordings';

  @override
  String get navSettings => 'Settings';

  @override
  String get navMenu => 'Menu';

  @override
  String get navSongs => 'Songs';

  @override
  String get navKits => 'Kits';

  @override
  String get navProfile => 'Profile';

  @override
  String get performTutorial => 'Tutorial';

  @override
  String get performMoreOptions => 'More options';

  @override
  String get performBankA => 'A';

  @override
  String get performBankB => 'B';

  @override
  String performSwitchBank(String bank) {
    return 'Switch to bank $bank';
  }

  @override
  String get performStopAll => 'Stop all';

  @override
  String performSpeed(double value) {
    final intl.NumberFormat valueNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String valueString = valueNumberFormat.format(value);

    return 'Speed $valueString×';
  }

  @override
  String get performRecord => 'Record';

  @override
  String get performRecording => 'Recording…';

  @override
  String get performStopRecording => 'Stop recording';

  @override
  String get performEditKit => 'Edit kit';

  @override
  String get performShareKit => 'Share kit';

  @override
  String get performSkins => 'Skins';

  @override
  String get performVideoTutorial => 'Video tutorial';

  @override
  String get performKitLoaded => 'Kit loaded!';

  @override
  String performLoadingKit(String kitName) {
    return 'Loading $kitName…';
  }

  @override
  String get performNoKit => 'No kit loaded';

  @override
  String get performPickKit => 'Pick a kit';

  @override
  String get performPadEmpty => 'Empty pad';

  @override
  String get performPadModeLoop => 'Loop';

  @override
  String get performPadModeOneShot => 'One-shot';

  @override
  String get performPadModeGate => 'Hold';

  @override
  String performPadLabel(int number) {
    return 'Pad $number';
  }

  @override
  String performPadSemantics(int number, String mode, String state) {
    return 'Pad $number, $mode, $state';
  }

  @override
  String get performPadStatePlaying => 'playing';

  @override
  String get performPadStateIdle => 'idle';

  @override
  String get performPadStatePending => 'waiting for the next bar';

  @override
  String get performQuantize => 'Quantize';

  @override
  String get performQuantizeBar => '1 bar';

  @override
  String get performQuantizeBeat => '1 beat';

  @override
  String get performQuantizeOff => 'Off';

  @override
  String performTempo(int bpm) {
    return '$bpm BPM';
  }

  @override
  String get performMetronome => 'Metronome';

  @override
  String get performKeyboardHint => 'Use your keyboard to play pads';

  @override
  String get performMidiLearn => 'MIDI learn';

  @override
  String get performControllerMode => 'Controller mode';

  @override
  String get performInspiredBy => 'Inspired by';

  @override
  String get libraryTitle => 'Kits';

  @override
  String get librarySearchHint => 'Search songs, artists or kits';

  @override
  String get libraryFeatured => 'Featured';

  @override
  String get libraryNewSongs => 'New songs';

  @override
  String get libraryTopSongs => 'Top songs';

  @override
  String get libraryGenre => 'Genre';

  @override
  String get libraryGenreHipHop => 'Hip-Hop';

  @override
  String get libraryGenreFunkBr => 'Funk BR';

  @override
  String get libraryGenreKpop => 'K-Pop';

  @override
  String get libraryGenreRock => 'Rock';

  @override
  String get libraryGenreDisco => 'Disco';

  @override
  String get libraryGenreEdm => 'EDM';

  @override
  String get libraryGenrePop => 'Pop';

  @override
  String get libraryGenreTrap => 'Trap';

  @override
  String get libraryGenreHouse => 'House';

  @override
  String get libraryGenreLatin => 'Latin';

  @override
  String get libraryKitBadge => 'Kit';

  @override
  String libraryKitGenre(String genre) {
    return '$genre music';
  }

  @override
  String libraryInspiredBy(String artist) {
    return 'Inspired by $artist';
  }

  @override
  String get libraryLetsPlay => 'Let\'s play';

  @override
  String get libraryDownloadKit => 'Download kit';

  @override
  String get libraryDownloaded => 'Downloaded';

  @override
  String get libraryNotDownloaded => 'Not downloaded';

  @override
  String libraryKitCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kits',
      one: '1 kit',
      zero: 'No kits',
    );
    return '$_temp0';
  }

  @override
  String libraryNoResults(String query) {
    return 'No results for “$query”';
  }

  @override
  String get libraryEmpty =>
      'Your library is empty. Import a kit to get started.';

  @override
  String get libraryImportKit => 'Import kit';

  @override
  String get libraryImportFromFile => 'Import from file';

  @override
  String get libraryImportFromDevices => 'Import from my devices';

  @override
  String get libraryImportLinkHint => 'Paste a kit link';

  @override
  String get libraryMyKits => 'My kits';

  @override
  String get libraryFavorites => 'Favorites';

  @override
  String get libraryAddFavorite => 'Add to favorites';

  @override
  String get libraryRemoveFavorite => 'Remove from favorites';

  @override
  String get libraryRecentlyPlayed => 'Recently played';

  @override
  String libraryNewKitAvailable(String kitName) {
    return 'New kit: $kitName';
  }

  @override
  String get librarySortBy => 'Sort by';

  @override
  String get librarySortName => 'Name';

  @override
  String get librarySortRecent => 'Recent';

  @override
  String get libraryDeleteKitTitle => 'Delete kit?';

  @override
  String libraryDeleteKitBody(String kitName) {
    return '“$kitName” and its sounds will be removed from this device.';
  }

  @override
  String get kitEditorTitle => 'Edit kit';

  @override
  String get kitEditorNewKit => 'New kit';

  @override
  String get kitEditorKitName => 'Kit name';

  @override
  String get kitEditorKitNameHint => 'My kit';

  @override
  String get kitEditorDescription => 'Description';

  @override
  String get kitEditorColor => 'Color';

  @override
  String get kitEditorPadColor => 'Pad color';

  @override
  String get kitEditorPadMode => 'Pad mode';

  @override
  String get kitEditorChokeGroup => 'Choke group';

  @override
  String kitEditorChokeGroupValue(int group) {
    return 'Group $group';
  }

  @override
  String get kitEditorPitch => 'Pitch';

  @override
  String kitEditorPitchValue(String semitones) {
    return '$semitones st';
  }

  @override
  String get kitEditorTimeStretch => 'Time stretch';

  @override
  String get kitEditorVolume => 'Volume';

  @override
  String get kitEditorPan => 'Pan';

  @override
  String get kitEditorTrim => 'Trim';

  @override
  String get kitEditorFadeIn => 'Fade in';

  @override
  String get kitEditorFadeOut => 'Fade out';

  @override
  String get kitEditorPreview => 'Preview';

  @override
  String get kitEditorClearPad => 'Clear pad';

  @override
  String get kitEditorCopyPad => 'Copy pad';

  @override
  String get kitEditorPastePad => 'Paste pad';

  @override
  String get kitEditorSaveKit => 'Save kit';

  @override
  String get kitEditorSaved => 'Kit saved';

  @override
  String get kitEditorUnsavedTitle => 'Discard changes?';

  @override
  String get kitEditorUnsavedBody => 'You have unsaved changes to this kit.';

  @override
  String get kitEditorDiscard => 'Discard';

  @override
  String get kitEditorSelectPad => 'Select a pad to load a sound';

  @override
  String kitEditorMaxLength(int seconds) {
    return 'Sounds are limited to $seconds seconds';
  }

  @override
  String get loadSoundTitle => 'Load sound';

  @override
  String get loadSoundImportFrom => 'Import from';

  @override
  String get loadSoundRecordingFrom => 'Recording from';

  @override
  String get loadSoundSourceSongs => 'Built-in songs';

  @override
  String get loadSoundSourceMicrophone => 'Microphone';

  @override
  String get loadSoundSourceFiles => 'Files';

  @override
  String get loadSoundSourceKits => 'Kits';

  @override
  String get loadSoundSourceRecordings => 'Recordings';

  @override
  String get loadSoundHoldToRecord => 'Hold to record';

  @override
  String loadSoundElapsed(int seconds) {
    return '${seconds}s';
  }

  @override
  String get recordStart => 'Start recording';

  @override
  String get recordStop => 'Stop recording';

  @override
  String get recordSaveTitle => 'Save recording';

  @override
  String get recordNameHint => 'Recording name';

  @override
  String recordDefaultName(int number) {
    return 'Track $number';
  }

  @override
  String get recordSaved => 'Recording saved';

  @override
  String get recordDiscardTitle => 'Discard recording?';

  @override
  String get worksTitle => 'Recordings';

  @override
  String get worksEmpty =>
      'No recordings yet. Tap record to capture your first track.';

  @override
  String worksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recordings',
      one: '1 recording',
      zero: 'No recordings',
    );
    return '$_temp0';
  }

  @override
  String worksRecordedOn(DateTime date) {
    final intl.DateFormat dateDateFormat = intl.DateFormat.yMMMd(localeName);
    final String dateString = dateDateFormat.format(date);

    return 'Recorded $dateString';
  }

  @override
  String get worksExportWav => 'Export WAV';

  @override
  String get worksLoop => 'Loop playback';

  @override
  String get worksShuffle => 'Shuffle';

  @override
  String get worksDeleteTitle => 'Delete recording?';

  @override
  String worksDeleteBody(String name) {
    return '“$name” will be permanently deleted.';
  }

  @override
  String get worksRenameTitle => 'Rename recording';

  @override
  String get tutorialTitle => 'Tutorial';

  @override
  String tutorialStep(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get tutorialTapHighlighted => 'Tap the highlighted pads';

  @override
  String tutorialSwitchBank(String bank) {
    return 'Switch to bank $bank';
  }

  @override
  String get tutorialComplete => 'Great job! Tutorial complete';

  @override
  String get tutorialRestart => 'Restart';

  @override
  String get tutorialExit => 'Exit tutorial';

  @override
  String tutorialProgress(int percent) {
    return '$percent% complete';
  }

  @override
  String get tutorialUnavailable => 'This kit has no tutorial yet';

  @override
  String get tutorialWatchVideo => 'Watch video';

  @override
  String get skinTitle => 'Skins';

  @override
  String get skinNeon => 'Neon';

  @override
  String get skinOutline => 'Outline';

  @override
  String get skinLight => 'Light';

  @override
  String get skinCustom => 'Custom';

  @override
  String get skinApply => 'Apply skin';

  @override
  String get skinApplied => 'Skin applied';

  @override
  String get skinEditorTitle => 'Skin editor';

  @override
  String get skinEditorNew => 'New skin';

  @override
  String skinEditorBasedOn(String skin) {
    return 'Based on $skin';
  }

  @override
  String get skinEditorNameHint => 'Skin name';

  @override
  String get skinEditorGroupSurface => 'Backgrounds';

  @override
  String get skinEditorGroupText => 'Text';

  @override
  String get skinEditorGroupAccent => 'Accent';

  @override
  String get skinEditorGroupPad => 'Pads';

  @override
  String get skinEditorGroupPalette => 'Pad palette';

  @override
  String skinEditorPaletteRole(int index) {
    return 'Color $index';
  }

  @override
  String get skinEditorCore => 'Center';

  @override
  String get skinEditorMid => 'Middle';

  @override
  String get skinEditorEdge => 'Edge';

  @override
  String get skinEditorGlow => 'Glow';

  @override
  String get skinEditorCornerRadius => 'Corner radius';

  @override
  String get skinEditorGlowIntensity => 'Glow intensity';

  @override
  String get skinEditorResetToken => 'Reset to default';

  @override
  String get skinEditorResetAll => 'Reset all';

  @override
  String get skinEditorExport => 'Export skin';

  @override
  String get skinEditorImport => 'Import skin';

  @override
  String get skinEditorImportInvalid => 'This skin file is invalid';

  @override
  String skinEditorImportIgnored(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count settings from a newer version were ignored',
      one: '1 setting from a newer version was ignored',
    );
    return '$_temp0';
  }

  @override
  String skinEditorChangeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes',
      one: '1 change',
      zero: 'No changes',
    );
    return '$_temp0';
  }

  @override
  String get skinEditorDeleteTitle => 'Delete skin?';

  @override
  String get skinPresetDefault => 'Default';

  @override
  String get skinPresetNumber => 'Number';

  @override
  String get skinPresetChristmas => 'Christmas';

  @override
  String get skinPresetPets => 'Pets';

  @override
  String get skinPresetCover => 'Cover';

  @override
  String get skinPresetBroken => 'Broken';

  @override
  String get skinPresetMuertos => 'Muertos';

  @override
  String get skinPresetCrazy => 'Crazy';

  @override
  String get skinPresetLaunchpad => 'Launchpad';

  @override
  String get skinPresetCrafts => 'Crafts';

  @override
  String get skinPresetPolished => 'Polished';

  @override
  String get skinPresetClean => 'Clean';

  @override
  String get skinPresetCircle => 'Circle';

  @override
  String get skinPresetSquare => 'Square';

  @override
  String get skinPresetLgbt => 'Rainbow';

  @override
  String get skinPresetHalloween => 'Halloween';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAudio => 'Audio';

  @override
  String get settingsOutputDevice => 'Output device';

  @override
  String get settingsInputDevice => 'Input device';

  @override
  String get settingsBufferSize => 'Buffer size';

  @override
  String settingsBufferSizeValue(int frames, double ms) {
    final intl.NumberFormat msNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String msString = msNumberFormat.format(ms);

    return '$frames samples ($msString ms)';
  }

  @override
  String get settingsSampleRate => 'Sample rate';

  @override
  String settingsSampleRateValue(int rate) {
    return '$rate Hz';
  }

  @override
  String get settingsLatency => 'Latency';

  @override
  String get settingsMeasureLatency => 'Measure latency';

  @override
  String settingsLatencyValue(int ms) {
    return '$ms ms';
  }

  @override
  String get settingsLanguage => 'Language';

  @override
  String settingsLanguageSystem(String language) {
    return 'System default ($language)';
  }

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsSkin => 'Skin';

  @override
  String get settingsAnimatePads => 'Animate pads';

  @override
  String get settingsReduceMotion => 'Reduce motion';

  @override
  String get settingsHaptics => 'Haptic feedback';

  @override
  String get settingsKeepScreenOn => 'Keep screen on';

  @override
  String get settingsMidi => 'MIDI';

  @override
  String get settingsMidiDevices => 'MIDI devices';

  @override
  String get settingsMidiNone => 'No MIDI devices connected';

  @override
  String get settingsKeyboardMapping => 'Keyboard mapping';

  @override
  String get settingsStorage => 'Storage';

  @override
  String settingsStorageUsed(String size) {
    return '$size used';
  }

  @override
  String get settingsClearCache => 'Clear cache';

  @override
  String get settingsCacheCleared => 'Cache cleared';

  @override
  String get settingsAbout => 'About';

  @override
  String settingsVersion(String version) {
    return 'Version $version';
  }

  @override
  String get settingsLicenses => 'Open-source licenses';

  @override
  String get settingsPrivacy => 'Privacy';

  @override
  String get settingsResearchNotice =>
      'UltraPads is an open-source research project (Apache-2.0).';

  @override
  String get hubTitle => 'My devices';

  @override
  String get hubDescription =>
      'Sync your library and use your phone as a pad controller over the local network.';

  @override
  String get hubEnable => 'Run hub on this device';

  @override
  String hubRunning(String address) {
    return 'Hub running at $address';
  }

  @override
  String get hubStopped => 'Hub stopped';

  @override
  String get hubDiscovering => 'Looking for devices…';

  @override
  String get hubNoDevices => 'No devices found on this network';

  @override
  String get hubDeviceOnline => 'Online';

  @override
  String get hubDeviceOffline => 'Offline';

  @override
  String hubDeviceLastSeen(String time) {
    return 'Last seen $time';
  }

  @override
  String hubDeviceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count paired devices',
      one: '1 paired device',
      zero: 'No paired devices',
    );
    return '$_temp0';
  }

  @override
  String get pairingNewDevice => 'Pair new device';

  @override
  String get pairingCodeTitle => 'Pairing code';

  @override
  String pairingCodeBody(String code) {
    return 'Enter this code on your other device: $code';
  }

  @override
  String get pairingEnterCode => 'Enter the code shown on your other device';

  @override
  String pairingConfirm(String deviceName) {
    return 'Pair with $deviceName?';
  }

  @override
  String pairingSuccess(String deviceName) {
    return 'Paired with $deviceName';
  }

  @override
  String get pairingFailed => 'Pairing failed. Check the code and try again.';

  @override
  String get pairingExpired => 'The code has expired';

  @override
  String get pairingUnpair => 'Unpair';

  @override
  String pairingUnpairConfirm(String deviceName) {
    return 'Unpair $deviceName? It will stop syncing with this device.';
  }

  @override
  String get pairingOwnDevicesOnly => 'Only pair devices you own.';

  @override
  String get pairingSameNetwork =>
      'Both devices must be on the same Wi-Fi network.';

  @override
  String get hubSyncLibrary => 'Sync library';

  @override
  String hubSyncProgress(int done, int total) {
    return 'Syncing $done of $total…';
  }

  @override
  String get hubSyncDone => 'Library is up to date';

  @override
  String hubSyncConflicts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count conflicts need attention',
      one: '1 conflict needs attention',
    );
    return '$_temp0';
  }

  @override
  String get hubUseAsController => 'Use as controller';

  @override
  String hubControlling(String deviceName) {
    return 'Controlling $deviceName';
  }

  @override
  String hubDisconnected(String deviceName) {
    return 'Disconnected from $deviceName';
  }

  @override
  String hubRoundTrip(int ms) {
    return 'Round trip $ms ms';
  }

  @override
  String get errorGeneric => 'Something went wrong';

  @override
  String get errorNetwork => 'No network connection';

  @override
  String get errorTimeout => 'The request timed out';

  @override
  String get errorDownloadFailed =>
      'Download failed. Check your connection and try again.';

  @override
  String get errorKitCorrupt => 'This kit is damaged and can\'t be loaded';

  @override
  String get errorKitNotFound => 'Kit not found';

  @override
  String get errorAudioDevice => 'Audio device unavailable';

  @override
  String errorAudioEngine(String code) {
    return 'Couldn\'t start the audio engine ($code)';
  }

  @override
  String get errorStorageFull => 'Not enough storage space';

  @override
  String errorFileRead(String fileName) {
    return 'Couldn\'t read “$fileName”';
  }

  @override
  String errorFileWrite(String fileName) {
    return 'Couldn\'t save “$fileName”';
  }

  @override
  String get errorUnsupportedFormat => 'This file format isn\'t supported';

  @override
  String get errorRecordingFailed => 'Recording failed';

  @override
  String get errorPermissionDenied => 'Permission denied';

  @override
  String errorDeviceUnreachable(String deviceName) {
    return 'Can\'t reach $deviceName';
  }

  @override
  String errorVersionMismatch(String deviceName) {
    return '$deviceName runs an incompatible version';
  }

  @override
  String get errorNameEmpty => 'Name can\'t be empty';

  @override
  String errorNameTooLong(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'Name must be at most $max characters',
      one: 'Name must be at most 1 character',
    );
    return '$_temp0';
  }

  @override
  String get errorNameTaken => 'That name is already in use';

  @override
  String get permissionMicrophoneTitle => 'Microphone access';

  @override
  String get permissionMicrophoneBody =>
      'UltraPads uses the microphone to record sounds into your pads. Recordings stay on your device.';

  @override
  String get permissionStorageTitle => 'File access';

  @override
  String get permissionStorageBody =>
      'Allow file access to import audio and export your recordings.';

  @override
  String get permissionLocalNetworkTitle => 'Local network';

  @override
  String get permissionLocalNetworkBody =>
      'Used only to find and connect your own devices on this Wi-Fi.';

  @override
  String get permissionBluetoothTitle => 'Bluetooth MIDI';

  @override
  String get permissionBluetoothBody =>
      'Allow Bluetooth to connect wireless MIDI controllers.';

  @override
  String get permissionNotificationsTitle => 'Notifications';

  @override
  String get permissionNotificationsBody =>
      'Get notified when a sync or export finishes.';

  @override
  String get permissionAllow => 'Allow';

  @override
  String get permissionOpenSettings => 'Open settings';

  @override
  String get permissionDeniedForever =>
      'Permission was denied. You can enable it in system settings.';

  @override
  String shareKitMessage(String kitName) {
    return 'Play my kit “$kitName” on UltraPads';
  }

  @override
  String shareRecordingMessage(String name) {
    return 'Listen to “$name”, made with UltraPads';
  }

  @override
  String get shareLinkCopied => 'Link copied';

  @override
  String get a11yOpenMenu => 'Open menu';

  @override
  String get a11yCloseSheet => 'Close panel';

  @override
  String a11yKitCover(String kitName) {
    return 'Cover of $kitName';
  }

  @override
  String a11yWaveform(String name) {
    return 'Waveform of $name';
  }

  @override
  String a11yProgress(int percent) {
    return '$percent percent';
  }

  @override
  String get timeJustNow => 'Just now';

  @override
  String timeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago',
      one: '1 minute ago',
    );
    return '$_temp0';
  }

  @override
  String timeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String timeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: 'Yesterday',
    );
    return '$_temp0';
  }

  @override
  String unitSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seconds',
      one: '1 second',
    );
    return '$_temp0';
  }

  @override
  String get onboardingMakeMusicTitle => 'Make your own music!';

  @override
  String get onboardingRhythmsTitle => 'Enjoy the best rhythms';

  @override
  String get onboardingLoopsTitle => 'Discover DJ loops & beats!';

  @override
  String get onboardingStyleTitle => 'Choose your style';

  @override
  String get onboardingShareTitle => 'Share your music';

  @override
  String get onboardingStart => 'Get started';

  @override
  String onboardingPlayStyle(String choice) {
    String _temp0 = intl.Intl.selectLogic(choice, {
      'solo': 'Play solo',
      'jam': 'Jam with friends',
      'other': 'Just exploring',
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
  String get settingsClassicPads => 'Classic pad animation';

  @override
  String settingsEngineBackend(String name) {
    return 'Audio engine: $name';
  }

  @override
  String get settingsEngineFallback =>
      'Native audio engine unavailable — running in demo mode';

  @override
  String get errorEngineUnsupported =>
      'The audio engine doesn\'t support this yet';

  @override
  String get loadSoundPickSample => 'Choose a sound';

  @override
  String get hubThisDevice => 'This device';

  @override
  String get hubNearbyDevices => 'Nearby devices';

  @override
  String get settingsPrivateAssets => 'Private asset pack';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get performLearnToPlay => 'Learn to play';

  @override
  String get performBackToTools => 'Back';

  @override
  String get performSpeedNormal => 'Normal';

  @override
  String get performSpeedSlow => 'Slow';

  @override
  String get performSpeedVerySlow => 'Very slow';

  @override
  String get tutorialPerfect => 'Perfect';

  @override
  String get tutorialTooFast => 'Too fast';

  @override
  String get tutorialTooSlow => 'Too slow';

  @override
  String get tutorialMiss => 'Miss';

  @override
  String get tutorialPressWhenFull => 'Press the pad when it\'s fully filled';

  @override
  String get tutorialPlayDemo => 'Play';

  @override
  String get navFeed => 'Feed';

  @override
  String get librarySeeAll => 'See all';

  @override
  String get libraryArtists => 'Artists';

  @override
  String get libraryRecommended => 'Recommended for you';

  @override
  String get libraryOpenKit => 'Open kit';

  @override
  String get kitEditorEditPad => 'Edit pad';

  @override
  String get kitEditorEditFile => 'Edit file';

  @override
  String get kitEditorClone => 'Clone';

  @override
  String get kitEditorGroup => 'Group';

  @override
  String get kitEditorLoop => 'Loop';

  @override
  String get kitEditorReplaceTitle => 'Replace this sound?';

  @override
  String get recordSaveAndShare => 'Save and share';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingChooseStyleBody =>
      'Pick the styles you like and we\'ll start you off with the right kits';

  @override
  String get settingsDeveloper => 'Developer';

  @override
  String get settingsDesignGallery => 'Design gallery';

  @override
  String get settingsGalleryTokens => 'Tokens';

  @override
  String get settingsGalleryComponents => 'Components';

  @override
  String get settingsGallerySkins => 'Themes & skins';

  @override
  String get settingsGalleryMotion => 'Motion';

  @override
  String get settingsGalleryPrimitive => 'Primitive colors';

  @override
  String get settingsGallerySemantic => 'Semantic colors';

  @override
  String get settingsGalleryRadii => 'Corner radius';

  @override
  String get settingsGallerySpacing => 'Spacing';

  @override
  String get settingsGalleryTypography => 'Typography';

  @override
  String get settingsGalleryGlow => 'Glow & shadow';

  @override
  String get settingsGalleryDurations => 'Durations & curves';

  @override
  String get settingsGalleryReplay => 'Replay';

  @override
  String get settingsGalleryStates => 'States';

  @override
  String get settingsGalleryDisabled => 'Disabled';

  @override
  String get settingsGalleryPressed => 'Pressed';

  @override
  String get hubLocalAddresses => 'Addresses of this device';

  @override
  String get hubAddressHint =>
      'If your phone can\'t find this device, enter one of these addresses on it.';

  @override
  String get pairingNewCode => 'New code';

  @override
  String pairingValidUntil(String time) {
    return 'Valid until $time, up to 5 attempts';
  }

  @override
  String get hubTrustedDevices => 'Trusted devices';

  @override
  String get hubRevoke => 'Revoke';

  @override
  String hubRevokeConfirm(String deviceName) {
    return 'Revoke $deviceName? It will no longer be able to sync with or control this device.';
  }

  @override
  String hubRemoteControlling(String deviceName) {
    return '$deviceName is controlling this device';
  }

  @override
  String get hubManualAddress => 'Enter address manually';

  @override
  String get hubManualAddressHint => 'IP or IP:port, e.g. 192.168.1.10:47100';

  @override
  String get hubConnect => 'Connect';

  @override
  String hubProbeFailed(String address) {
    return 'Couldn\'t reach $address';
  }

  @override
  String get hubLocalEcho => 'Also play on this device';

  @override
  String get hubLocalEchoHint => 'By default only the controlled device plays';

  @override
  String get hubStopControlling => 'Stop controlling';

  @override
  String hubSyncFinished(int down, int up) {
    return 'Sync finished: $down downloaded, $up uploaded';
  }

  @override
  String get hubSyncStarting => 'Preparing sync…';

  @override
  String hubDeviceId(String id) {
    return 'Device ID: $id';
  }

  @override
  String hubErrorOp(String op) {
    return 'Hub operation failed ($op)';
  }

  @override
  String get settingsAudioStatus => 'Audio status';

  @override
  String settingsAudioStatusValue(
    String host,
    String device,
    int channels,
    String format,
  ) {
    return '$host · $device · $channels ch $format';
  }

  @override
  String get settingsAudioStopped => 'Audio output is not running';

  @override
  String get performVideoPlatform => 'YouTube';

  @override
  String get performVideoOpenFailed => 'Couldn\'t open the video link';

  @override
  String tutorialFirstGuideStep(int step, int total) {
    return 'STEP $step/$total';
  }

  @override
  String get tutorialFirstGuidePad => 'Tap a pad to start your first beat!';

  @override
  String get tutorialFirstGuideLearn =>
      'Tap LEARN TO PLAY to learn the whole song step by step.';

  @override
  String get tutorialFirstGuideMore =>
      'Recording, skins, kit editing and settings live under ⋮.';

  @override
  String get tutorialFirstGuideSongs =>
      'Tap SONGS to open the library and pick more kits.';

  @override
  String get tutorialFirstGuideDone => 'LET\'S PLAY';

  @override
  String get settingsReplayGuide => 'Show the first-run guide again';

  @override
  String get settingsReplayGuideDone =>
      'The guide will show on the perform screen';

  @override
  String get settingsBufferSizeSystem => 'System default';

  @override
  String get settingsUpdateTitle => 'Software update';

  @override
  String get settingsUpdateAutoCheck => 'Check for updates automatically';

  @override
  String get settingsUpdateAutoCheckHint =>
      'Asks the update server once after launch; sends nothing about you or this device.';

  @override
  String get settingsUpdateCheckNow => 'Check for updates';

  @override
  String get settingsUpdateChecking => 'Checking for updates…';

  @override
  String get settingsUpdateUpToDate => 'UltraPads is up to date';

  @override
  String get settingsUpdateCheckFailed => 'Couldn\'t check for updates';

  @override
  String settingsUpdateAvailable(String version) {
    return 'Version $version is available';
  }

  @override
  String settingsUpdateAvailableToast(String version) {
    return 'UltraPads $version is available — update it in Settings';
  }

  @override
  String get settingsUpdateNow => 'Update';

  @override
  String settingsUpdateDownloading(int percent) {
    return 'Downloading… $percent%';
  }

  @override
  String settingsUpdateDownloadingGithub(int percent) {
    return 'Downloading from GitHub… $percent%';
  }

  @override
  String get settingsUpdateRestart => 'Restart to finish';

  @override
  String get settingsUpdateInstall => 'Install';

  @override
  String get settingsUpdateInstallPermission =>
      'Allow UltraPads to install apps in the next screen, then tap Install again.';

  @override
  String get settingsUpdateFailed => 'Update failed';

  @override
  String get settingsUpdateReleaseNotes => 'What\'s new';

  @override
  String get settingsUpdateDownloadPage => 'Download page';

  @override
  String get settingsUpdateManualHint =>
      'This copy wasn\'t installed with the install script, so it can\'t update itself. Get the new version from the download page.';

  @override
  String performSoundGroup(String name) {
    return 'Sound group $name';
  }

  @override
  String get performFirstGuideGroups =>
      'Each song can have several sound groups — tap A, B… to switch. Sounds already playing keep going.';

  @override
  String get kitEditorGroups => 'Sound groups';

  @override
  String get kitEditorAddGroup => 'Add a sound group';

  @override
  String kitEditorMoveGroupLeft(String name) {
    return 'Move group $name left';
  }

  @override
  String kitEditorMoveGroupRight(String name) {
    return 'Move group $name right';
  }

  @override
  String kitEditorDeleteGroup(String name) {
    return 'Delete group $name';
  }

  @override
  String kitEditorDeleteGroupTitle(String name) {
    return 'Delete sound group $name?';
  }

  @override
  String kitEditorDeleteGroupBody(int count) {
    return 'Its $count pads are removed and the groups after it move up.';
  }

  @override
  String get settingsOutputDeviceSystem => 'Follow the system';

  @override
  String settingsOutputDeviceFallback(String name) {
    return '$name is unavailable — using the system output';
  }

  @override
  String get navCatalog => 'Official';

  @override
  String get libraryCatalogSearchHint => 'Search official songs';

  @override
  String get libraryCatalogFilters => 'Filters';

  @override
  String get libraryCatalogFilterLicense => 'License';

  @override
  String get libraryCatalogFilterGenre => 'Genre';

  @override
  String get libraryCatalogFilterBpm => 'Tempo';

  @override
  String libraryCatalogBpmRange(int min, int max) {
    return '$min–$max BPM';
  }

  @override
  String get libraryCatalogBpmAny => 'Any tempo';

  @override
  String get libraryCatalogSortNewest => 'Newest';

  @override
  String get libraryCatalogSortBpm => 'BPM';

  @override
  String get libraryCatalogSortTitle => 'A–Z';

  @override
  String get libraryCatalogClearFilters => 'Clear filters';

  @override
  String get libraryCatalogFavoritesOnly => 'Favorites';

  @override
  String get libraryCatalogRecent => 'Recently played';

  @override
  String libraryCatalogTotal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs',
      one: '1 song',
      zero: 'No songs',
    );
    return '$_temp0';
  }

  @override
  String get libraryCatalogEmpty => 'No songs match these filters.';

  @override
  String get libraryCatalogEmptyFavorites =>
      'Tap the heart on a song to keep it here.';

  @override
  String get libraryCatalogLoadFailed => 'Couldn’t reach the official catalog.';

  @override
  String get libraryCatalogLoadFailedOffline =>
      'You’re offline. Check your connection and try again.';

  @override
  String get libraryCatalogDownload => 'Download';

  @override
  String get libraryCatalogDownloaded => 'Downloaded';

  @override
  String get libraryCatalogUpdateAvailable => 'Update';

  @override
  String get libraryCatalogPlay => 'Play';

  @override
  String libraryCatalogDownloadingPercent(int percent) {
    return 'Downloading $percent%';
  }

  @override
  String get libraryCatalogDownloadFailed => 'Download failed. Try again.';

  @override
  String get libraryCatalogDownloadCorrupt =>
      'The file didn’t pass verification. Try again.';

  @override
  String get libraryCatalogDownloadNotFound =>
      'This song is no longer available.';

  @override
  String libraryCatalogImportedToast(String name) {
    return '$name is ready to play';
  }

  @override
  String get libraryCatalogAddFavorite => 'Add to favorites';

  @override
  String get libraryCatalogRemoveFavorite => 'Remove from favorites';

  @override
  String libraryCatalogByArtist(String artist) {
    return 'by $artist';
  }

  @override
  String get libraryCatalogDetailCredits => 'Credits';

  @override
  String get libraryCatalogDetailLicense => 'License';

  @override
  String get libraryCatalogDetailSource => 'Source';

  @override
  String get libraryCatalogDetailOpenSource => 'Open source page';

  @override
  String get libraryCatalogDetailOpenLicense => 'Read the license';

  @override
  String libraryCatalogDetailGroups(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count banks',
      one: '1 bank',
    );
    return '$_temp0';
  }

  @override
  String libraryCatalogDetailPads(int count) {
    return '$count pads';
  }

  @override
  String libraryCatalogDetailLoop(String secs) {
    return '${secs}s loop';
  }

  @override
  String libraryCatalogDetailSizeMb(String mb) {
    return '$mb MB';
  }

  @override
  String get libraryCatalogOriginAlbum => 'Multitrack album';

  @override
  String get libraryCatalogOriginOnline => 'Community';

  @override
  String get libraryCatalogOriginSynth => 'Original synthesis';

  @override
  String get libraryCatalogOriginUgc => 'Community upload';

  @override
  String get libraryCatalogNotFound =>
      'This song isn’t in the catalog anymore.';

  @override
  String get libraryLicenseCc0Hint =>
      'CC0: public domain. Free to use, no credit needed.';

  @override
  String get libraryLicensePdHint =>
      'Public domain: free to use, no credit needed.';

  @override
  String get libraryLicenseByHint =>
      'Attribution: credit the creator when you share or publish.';

  @override
  String get libraryLicenseSaHint =>
      'Share-alike: works built on this must use the same license.';

  @override
  String get libraryLicenseNcHint => 'Non-commercial: not for commercial use.';

  @override
  String get settingsAccountTitle => 'Account';

  @override
  String get settingsAccountSignIn => 'Sign in';

  @override
  String get settingsAccountSignInHint =>
      'Keep favorites and recently played in sync across your devices.';

  @override
  String get settingsAccountSigningIn => 'Finish signing in in your browser…';

  @override
  String get settingsAccountSignInCancel => 'Cancel sign-in';

  @override
  String settingsAccountSignedInAs(String account) {
    return 'Signed in as $account';
  }

  @override
  String get settingsAccountSignOut => 'Sign out';

  @override
  String get settingsAccountManage => 'Manage account';

  @override
  String get settingsAccountSignInFailed =>
      'Sign-in didn’t complete. Try again.';

  @override
  String get settingsAccountNotConfigured =>
      'Sign-in isn’t available in this build.';

  @override
  String get settingsAccountSyncing => 'Syncing…';

  @override
  String settingsAccountPendingSync(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes waiting to sync',
      one: '1 change waiting to sync',
    );
    return '$_temp0';
  }

  @override
  String get settingsAccountSignedOutToast => 'Signed out';

  @override
  String get settingsAccountSignedInToast => 'Signed in';

  @override
  String get settingsAccountLoopbackTitle => 'Signed in';

  @override
  String get settingsAccountLoopbackBody =>
      'You can close this tab and go back to UltraPads.';

  @override
  String get shareExportCreditsTitle => 'This recording uses licensed material';

  @override
  String get shareExportCreditsNc => 'Non-commercial use only.';

  @override
  String get shareExportCreditsSa => 'Share your work under the same license.';

  @override
  String shareExportCreditsShareText(String credits) {
    return 'Credits:\n$credits';
  }

  @override
  String get librarySplitEntryTitle => 'Split a song into a kit';

  @override
  String get librarySplitEntrySubtitle =>
      'Pick a song on this device; it is cut into sections';

  @override
  String get librarySplitTitle => 'Split song';

  @override
  String get librarySplitIntro =>
      'Each group (A, B, C…) is one full section of the song and each pad in it is one instrument — turn on a whole group to hear the section. Everything runs on this device; the song is never uploaded.';

  @override
  String get librarySplitModeSeparate =>
      'Separate instruments (drums / bass / other / vocals)';

  @override
  String librarySplitModeSeparateReady(String gb) {
    return 'Model ready. Needs about $gb GB of memory and a few minutes';
  }

  @override
  String librarySplitModeSeparateDownload(int mb, String gb) {
    return 'First use downloads the separation model (about $mb MB). Needs about $gb GB of memory and a few minutes';
  }

  @override
  String librarySplitModeSeparateNoMemory(String gb) {
    return 'Not enough free memory on this device (about $gb GB needed) — use quick split or a device with more memory';
  }

  @override
  String get librarySplitModeQuick => 'Quick split (whole mix)';

  @override
  String get librarySplitModeQuickHint =>
      'No separation: the first pad of each group is the whole section, the rest are 2-bar and 1-bar fragments. Takes seconds';

  @override
  String get librarySplitStart => 'Start';

  @override
  String librarySplitStageDownloadingModel(int percent) {
    return 'Downloading the separation model… $percent%';
  }

  @override
  String get librarySplitStageDecoding => 'Reading the song…';

  @override
  String get librarySplitStageLoadingModel => 'Loading the separation model…';

  @override
  String get librarySplitStageAnalyzing => 'Analyzing tempo and bars…';

  @override
  String librarySplitStageSeparating(int percent) {
    return 'Separating instruments… $percent%';
  }

  @override
  String get librarySplitStageBuilding => 'Building the kit…';

  @override
  String get librarySplitStageImporting => 'Importing into the library…';

  @override
  String librarySplitDone(String name, int sections, int bpm) {
    return 'Created “$name”: $sections sections, about $bpm BPM';
  }

  @override
  String get librarySplitUnreliable =>
      'The tempo of this song is not steady, so bar lines may be slightly off; you can fine-tune them in the kit editor.';

  @override
  String get librarySplitLoadKit => 'Load and play';

  @override
  String get librarySplitCancelled => 'Cancelled';

  @override
  String get librarySplitErrorTooShort =>
      'The song is too short to make a 4-bar section.';

  @override
  String get librarySplitErrorNoGrid =>
      'No steady beat was found — the song may have no clear pulse or a changing tempo.';

  @override
  String get librarySplitErrorMemory =>
      'Not enough free memory. Close other apps and retry, or use quick split.';

  @override
  String get librarySplitErrorDecode => 'This audio file could not be read.';

  @override
  String get librarySplitErrorModel =>
      'The separation model could not be loaded. Remove it and download it again.';

  @override
  String get librarySplitErrorModelChecksum =>
      'The downloaded model failed its checksum. Please retry.';

  @override
  String get librarySplitErrorModelDownload =>
      'The model download failed. Check your connection and retry.';

  @override
  String get librarySplitErrorGeneric => 'Splitting failed. Please retry.';

  @override
  String get libraryUgcMyUploads => 'My uploads';

  @override
  String get libraryUgcFilterOrigin => 'Source';

  @override
  String get libraryUgcOriginAll => 'All sources';

  @override
  String get libraryUgcCommunityBadge => 'Community';

  @override
  String get libraryUgcCommunityNotice =>
      'Shared by a community member. Credit and licence are declared by the uploader.';

  @override
  String libraryUgcUploadedBy(String credit) {
    return 'Credit: $credit';
  }

  @override
  String get libraryUgcReport => 'Report';

  @override
  String get libraryUgcReportTitle => 'Report this kit';

  @override
  String get libraryUgcReportReasonCopyright => 'Copyright infringement';

  @override
  String get libraryUgcReportReasonInappropriate => 'Inappropriate content';

  @override
  String get libraryUgcReportReasonOther => 'Something else';

  @override
  String get libraryUgcReportNoteHint =>
      'Details (optional, up to 500 characters)';

  @override
  String get libraryUgcReportSubmit => 'Send report';

  @override
  String get libraryUgcReportSent => 'Report received. Thank you.';

  @override
  String get libraryUgcReportOwn =>
      'This is your own upload, so you can’t report it.';

  @override
  String get libraryUgcReportSignIn => 'Sign in to report a kit.';

  @override
  String get libraryUgcReportGone => 'This kit is no longer public.';

  @override
  String get libraryUgcMyTitle => 'My uploads';

  @override
  String get libraryUgcSignInPrompt =>
      'Sign in to upload and manage your kits.';

  @override
  String get libraryUgcEmpty =>
      'No uploads yet. New uploads are private by default.';

  @override
  String get libraryUgcUploadAction => 'Upload a kit';

  @override
  String get libraryUgcVisibilityPrivate => 'Private';

  @override
  String get libraryUgcVisibilityPublic => 'Public';

  @override
  String get libraryUgcVisibilityHidden => 'Hidden (under review)';

  @override
  String get libraryUgcVisibilityTakenDown => 'Taken down';

  @override
  String get libraryUgcNoFile => 'No file yet';

  @override
  String get libraryUgcHiddenNote =>
      'Hidden for now after several reports. Waiting for review.';

  @override
  String get libraryUgcTakenDownNote =>
      'Taken down by the moderators. You can only delete it.';

  @override
  String get libraryUgcMakePublic => 'Make public';

  @override
  String get libraryUgcMakePrivate => 'Make private';

  @override
  String get libraryUgcPublicConfirmTitle => 'Share this kit publicly?';

  @override
  String get libraryUgcPublicConfirmBody =>
      'Anyone will be able to find and download it in the catalog, along with the credit and licence you entered. You can make it private again at any time; it can take up to a minute to take effect.';

  @override
  String get libraryUgcPublicConfirmOk => 'Make public';

  @override
  String get libraryUgcMadePublicToast => 'Now public';

  @override
  String get libraryUgcMadePrivateToast => 'Now private';

  @override
  String get libraryUgcDeleteTitle => 'Delete this upload?';

  @override
  String get libraryUgcDeleteBody =>
      'The entry and its cloud file are deleted permanently. People who already downloaded it keep their copy.';

  @override
  String get libraryUgcDeletedToast => 'Deleted';

  @override
  String get libraryUgcRestore => 'Download to this device';

  @override
  String libraryUgcRestoredToast(String name) {
    return '$name is ready to play';
  }

  @override
  String get libraryUgcPickKitTitle => 'Choose a kit to upload';

  @override
  String get libraryUgcPickKitEmpty => 'There are no kits to upload yet.';

  @override
  String get libraryUgcFormTitle => 'Upload a kit';

  @override
  String get libraryUgcFieldTitle => 'Title';

  @override
  String get libraryUgcFieldCredit => 'Credit';

  @override
  String get libraryUgcFieldCreditHint =>
      'Shown as written, e.g. author name / source';

  @override
  String get libraryUgcFieldLicense => 'Licence';

  @override
  String get libraryUgcFieldSourceUrl => 'Source link (optional)';

  @override
  String get libraryUgcFieldDescription => 'Description (optional)';

  @override
  String get libraryUgcDeclarationTitle => 'Where the material comes from';

  @override
  String get libraryUgcDeclarationOwn => 'My own work or recordings';

  @override
  String get libraryUgcDeclarationLicensed =>
      'Material licensed to me under the licence above';

  @override
  String get libraryUgcConfirmRights =>
      'I have the right to share this kit and agree to share it under the chosen licence';

  @override
  String get libraryUgcFormPrivateNote =>
      'Uploads are private by default. You can make one public later from My uploads.';

  @override
  String get libraryUgcFormErrTitle => 'Enter a title (up to 120 characters)';

  @override
  String get libraryUgcFormErrCredit => 'Enter a credit (up to 500 characters)';

  @override
  String get libraryUgcFormErrUrl =>
      'The source link must start with http:// or https://';

  @override
  String get libraryUgcFormErrConfirm =>
      'Please confirm you have the right to share it';

  @override
  String get libraryUgcSubmit => 'Upload';

  @override
  String get libraryUgcPhaseExporting => 'Packing the kit…';

  @override
  String get libraryUgcPhaseCreating => 'Creating the entry…';

  @override
  String libraryUgcPhaseUploading(int percent) {
    return 'Uploading $percent%';
  }

  @override
  String get libraryUgcUploadDone => 'Uploaded. It’s private for now.';

  @override
  String get libraryUgcErrTooLarge =>
      'The file is over 128 MB and can’t be uploaded.';

  @override
  String get libraryUgcErrQuota =>
      'You’ve reached the limit of 50 uploads. Delete some first.';

  @override
  String get libraryUgcErrInvalidKit =>
      'The server rejected the file as invalid or damaged in transit. Try again.';

  @override
  String get libraryUgcErrSignIn => 'Your sign-in has expired. Sign in again.';

  @override
  String get libraryUgcErrTakenDown => 'This entry has been taken down.';

  @override
  String get libraryUgcErrNoFile =>
      'There’s no file yet, so it can’t be made public.';

  @override
  String get libraryUgcErrBadForm =>
      'Some fields aren’t valid. Check them and try again.';

  @override
  String get libraryUgcErrGeneric => 'That didn’t work. Try again later.';
}
