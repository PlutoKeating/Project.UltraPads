import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'up_l10n_en.dart';
import 'up_l10n_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of UpL10n
/// returned by `UpL10n.of(context)`.
///
/// Applications need to include `UpL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/up_l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: UpL10n.localizationsDelegates,
///   supportedLocales: UpL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the UpL10n.supportedLocales
/// property.
abstract class UpL10n {
  UpL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static UpL10n of(BuildContext context) {
    return Localizations.of<UpL10n>(context, UpL10n)!;
  }

  static const LocalizationsDelegate<UpL10n> delegate = _UpL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// Name of this language written in itself; shown in the language picker.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get localeNativeName;

  /// Name of this language in English; shown as secondary text in the language picker.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get localeEnglishName;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get commonRename;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commonNext;

  /// No description provided for @commonSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get commonSkip;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get commonApply;

  /// No description provided for @commonReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get commonReset;

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// No description provided for @commonSeeMore.
  ///
  /// In en, this message translates to:
  /// **'See more'**
  String get commonSeeMore;

  /// No description provided for @commonShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get commonShare;

  /// No description provided for @commonPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get commonPlay;

  /// No description provided for @commonPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get commonPause;

  /// No description provided for @commonStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get commonStop;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get commonLoading;

  /// No description provided for @commonOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get commonOn;

  /// No description provided for @commonOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get commonOff;

  /// No description provided for @commonYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get commonYes;

  /// No description provided for @commonNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get commonNo;

  /// No description provided for @commonUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get commonUndo;

  /// No description provided for @commonRedo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get commonRedo;

  /// No description provided for @commonCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get commonCopy;

  /// No description provided for @commonPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get commonPaste;

  /// No description provided for @commonImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get commonImport;

  /// No description provided for @commonExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get commonExport;

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// No description provided for @commonRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get commonRemove;

  /// No description provided for @commonDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get commonDownload;

  /// Download progress label.
  ///
  /// In en, this message translates to:
  /// **'Downloading… {percent}%'**
  String commonDownloadProgress(int percent);

  /// No description provided for @commonUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get commonUnknown;

  /// No description provided for @commonNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get commonNew;

  /// No description provided for @commonTop.
  ///
  /// In en, this message translates to:
  /// **'Top'**
  String get commonTop;

  /// No description provided for @commonAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get commonAll;

  /// No description provided for @commonSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get commonSelect;

  /// No description provided for @commonGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get commonGotIt;

  /// No description provided for @commonLearnMore.
  ///
  /// In en, this message translates to:
  /// **'Learn more'**
  String get commonLearnMore;

  /// No description provided for @commonComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get commonComingSoon;

  /// No description provided for @commonNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get commonNone;

  /// Main navigation: pad performance screen.
  ///
  /// In en, this message translates to:
  /// **'Perform'**
  String get navPerform;

  /// No description provided for @navLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get navLibrary;

  /// No description provided for @navCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get navCreate;

  /// No description provided for @navRecordings.
  ///
  /// In en, this message translates to:
  /// **'Recordings'**
  String get navRecordings;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// Top-left menu button on the perform screen.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get navMenu;

  /// Chip on the perform screen that opens the song/kit library.
  ///
  /// In en, this message translates to:
  /// **'Songs'**
  String get navSongs;

  /// No description provided for @navKits.
  ///
  /// In en, this message translates to:
  /// **'Kits'**
  String get navKits;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// Toolbar chip that starts the guided tutorial.
  ///
  /// In en, this message translates to:
  /// **'Tutorial'**
  String get performTutorial;

  /// No description provided for @performMoreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get performMoreOptions;

  /// Label of pad bank A (first 12 pads). Usually kept as a Latin letter.
  ///
  /// In en, this message translates to:
  /// **'A'**
  String get performBankA;

  /// Label of pad bank B (pads 13-24). Usually kept as a Latin letter.
  ///
  /// In en, this message translates to:
  /// **'B'**
  String get performBankB;

  /// No description provided for @performSwitchBank.
  ///
  /// In en, this message translates to:
  /// **'Switch to bank {bank}'**
  String performSwitchBank(String bank);

  /// No description provided for @performStopAll.
  ///
  /// In en, this message translates to:
  /// **'Stop all'**
  String get performStopAll;

  /// Playback speed multiplier badge.
  ///
  /// In en, this message translates to:
  /// **'Speed {value}×'**
  String performSpeed(double value);

  /// No description provided for @performRecord.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get performRecord;

  /// No description provided for @performRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording…'**
  String get performRecording;

  /// No description provided for @performStopRecording.
  ///
  /// In en, this message translates to:
  /// **'Stop recording'**
  String get performStopRecording;

  /// No description provided for @performEditKit.
  ///
  /// In en, this message translates to:
  /// **'Edit kit'**
  String get performEditKit;

  /// No description provided for @performShareKit.
  ///
  /// In en, this message translates to:
  /// **'Share kit'**
  String get performShareKit;

  /// No description provided for @performSkins.
  ///
  /// In en, this message translates to:
  /// **'Skins'**
  String get performSkins;

  /// No description provided for @performVideoTutorial.
  ///
  /// In en, this message translates to:
  /// **'Video tutorial'**
  String get performVideoTutorial;

  /// No description provided for @performKitLoaded.
  ///
  /// In en, this message translates to:
  /// **'Kit loaded!'**
  String get performKitLoaded;

  /// No description provided for @performLoadingKit.
  ///
  /// In en, this message translates to:
  /// **'Loading {kitName}…'**
  String performLoadingKit(String kitName);

  /// No description provided for @performNoKit.
  ///
  /// In en, this message translates to:
  /// **'No kit loaded'**
  String get performNoKit;

  /// No description provided for @performPickKit.
  ///
  /// In en, this message translates to:
  /// **'Pick a kit'**
  String get performPickKit;

  /// No description provided for @performPadEmpty.
  ///
  /// In en, this message translates to:
  /// **'Empty pad'**
  String get performPadEmpty;

  /// No description provided for @performPadModeLoop.
  ///
  /// In en, this message translates to:
  /// **'Loop'**
  String get performPadModeLoop;

  /// No description provided for @performPadModeOneShot.
  ///
  /// In en, this message translates to:
  /// **'One-shot'**
  String get performPadModeOneShot;

  /// No description provided for @performPadModeGate.
  ///
  /// In en, this message translates to:
  /// **'Hold'**
  String get performPadModeGate;

  /// Accessibility name of a pad.
  ///
  /// In en, this message translates to:
  /// **'Pad {number}'**
  String performPadLabel(int number);

  /// Screen-reader description of a pad.
  ///
  /// In en, this message translates to:
  /// **'Pad {number}, {mode}, {state}'**
  String performPadSemantics(int number, String mode, String state);

  /// No description provided for @performPadStatePlaying.
  ///
  /// In en, this message translates to:
  /// **'playing'**
  String get performPadStatePlaying;

  /// No description provided for @performPadStateIdle.
  ///
  /// In en, this message translates to:
  /// **'idle'**
  String get performPadStateIdle;

  /// No description provided for @performPadStatePending.
  ///
  /// In en, this message translates to:
  /// **'waiting for the next bar'**
  String get performPadStatePending;

  /// No description provided for @performQuantize.
  ///
  /// In en, this message translates to:
  /// **'Quantize'**
  String get performQuantize;

  /// No description provided for @performQuantizeBar.
  ///
  /// In en, this message translates to:
  /// **'1 bar'**
  String get performQuantizeBar;

  /// No description provided for @performQuantizeBeat.
  ///
  /// In en, this message translates to:
  /// **'1 beat'**
  String get performQuantizeBeat;

  /// No description provided for @performQuantizeOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get performQuantizeOff;

  /// No description provided for @performTempo.
  ///
  /// In en, this message translates to:
  /// **'{bpm} BPM'**
  String performTempo(int bpm);

  /// No description provided for @performMetronome.
  ///
  /// In en, this message translates to:
  /// **'Metronome'**
  String get performMetronome;

  /// No description provided for @performKeyboardHint.
  ///
  /// In en, this message translates to:
  /// **'Use your keyboard to play pads'**
  String get performKeyboardHint;

  /// No description provided for @performMidiLearn.
  ///
  /// In en, this message translates to:
  /// **'MIDI learn'**
  String get performMidiLearn;

  /// No description provided for @performControllerMode.
  ///
  /// In en, this message translates to:
  /// **'Controller mode'**
  String get performControllerMode;

  /// No description provided for @performInspiredBy.
  ///
  /// In en, this message translates to:
  /// **'Inspired by'**
  String get performInspiredBy;

  /// No description provided for @libraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Kits'**
  String get libraryTitle;

  /// No description provided for @librarySearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search songs, artists or kits'**
  String get librarySearchHint;

  /// No description provided for @libraryFeatured.
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get libraryFeatured;

  /// No description provided for @libraryNewSongs.
  ///
  /// In en, this message translates to:
  /// **'New songs'**
  String get libraryNewSongs;

  /// No description provided for @libraryTopSongs.
  ///
  /// In en, this message translates to:
  /// **'Top songs'**
  String get libraryTopSongs;

  /// No description provided for @libraryGenre.
  ///
  /// In en, this message translates to:
  /// **'Genre'**
  String get libraryGenre;

  /// No description provided for @libraryGenreHipHop.
  ///
  /// In en, this message translates to:
  /// **'Hip-Hop'**
  String get libraryGenreHipHop;

  /// No description provided for @libraryGenreFunkBr.
  ///
  /// In en, this message translates to:
  /// **'Funk BR'**
  String get libraryGenreFunkBr;

  /// No description provided for @libraryGenreKpop.
  ///
  /// In en, this message translates to:
  /// **'K-Pop'**
  String get libraryGenreKpop;

  /// No description provided for @libraryGenreRock.
  ///
  /// In en, this message translates to:
  /// **'Rock'**
  String get libraryGenreRock;

  /// No description provided for @libraryGenreDisco.
  ///
  /// In en, this message translates to:
  /// **'Disco'**
  String get libraryGenreDisco;

  /// No description provided for @libraryGenreEdm.
  ///
  /// In en, this message translates to:
  /// **'EDM'**
  String get libraryGenreEdm;

  /// No description provided for @libraryGenrePop.
  ///
  /// In en, this message translates to:
  /// **'Pop'**
  String get libraryGenrePop;

  /// No description provided for @libraryGenreTrap.
  ///
  /// In en, this message translates to:
  /// **'Trap'**
  String get libraryGenreTrap;

  /// No description provided for @libraryGenreHouse.
  ///
  /// In en, this message translates to:
  /// **'House'**
  String get libraryGenreHouse;

  /// No description provided for @libraryGenreLatin.
  ///
  /// In en, this message translates to:
  /// **'Latin'**
  String get libraryGenreLatin;

  /// Small overline above a kit name on cards.
  ///
  /// In en, this message translates to:
  /// **'Kit'**
  String get libraryKitBadge;

  /// Kit card subtitle, e.g. 'Hip-Hop music'.
  ///
  /// In en, this message translates to:
  /// **'{genre} music'**
  String libraryKitGenre(String genre);

  /// No description provided for @libraryInspiredBy.
  ///
  /// In en, this message translates to:
  /// **'Inspired by {artist}'**
  String libraryInspiredBy(String artist);

  /// No description provided for @libraryLetsPlay.
  ///
  /// In en, this message translates to:
  /// **'Let\'s play'**
  String get libraryLetsPlay;

  /// No description provided for @libraryDownloadKit.
  ///
  /// In en, this message translates to:
  /// **'Download kit'**
  String get libraryDownloadKit;

  /// No description provided for @libraryDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get libraryDownloaded;

  /// No description provided for @libraryNotDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Not downloaded'**
  String get libraryNotDownloaded;

  /// ICU plural example.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No kits} =1{1 kit} other{{count} kits}}'**
  String libraryKitCount(int count);

  /// No description provided for @libraryNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results for “{query}”'**
  String libraryNoResults(String query);

  /// No description provided for @libraryEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your library is empty. Import a kit to get started.'**
  String get libraryEmpty;

  /// No description provided for @libraryImportKit.
  ///
  /// In en, this message translates to:
  /// **'Import kit'**
  String get libraryImportKit;

  /// No description provided for @libraryImportFromFile.
  ///
  /// In en, this message translates to:
  /// **'Import from file'**
  String get libraryImportFromFile;

  /// No description provided for @libraryImportFromDevices.
  ///
  /// In en, this message translates to:
  /// **'Import from my devices'**
  String get libraryImportFromDevices;

  /// No description provided for @libraryImportLinkHint.
  ///
  /// In en, this message translates to:
  /// **'Paste a kit link'**
  String get libraryImportLinkHint;

  /// No description provided for @libraryMyKits.
  ///
  /// In en, this message translates to:
  /// **'My kits'**
  String get libraryMyKits;

  /// No description provided for @libraryFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get libraryFavorites;

  /// No description provided for @libraryAddFavorite.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get libraryAddFavorite;

  /// No description provided for @libraryRemoveFavorite.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get libraryRemoveFavorite;

  /// No description provided for @libraryRecentlyPlayed.
  ///
  /// In en, this message translates to:
  /// **'Recently played'**
  String get libraryRecentlyPlayed;

  /// No description provided for @libraryNewKitAvailable.
  ///
  /// In en, this message translates to:
  /// **'New kit: {kitName}'**
  String libraryNewKitAvailable(String kitName);

  /// No description provided for @librarySortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get librarySortBy;

  /// No description provided for @librarySortName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get librarySortName;

  /// No description provided for @librarySortRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get librarySortRecent;

  /// No description provided for @libraryDeleteKitTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete kit?'**
  String get libraryDeleteKitTitle;

  /// No description provided for @libraryDeleteKitBody.
  ///
  /// In en, this message translates to:
  /// **'“{kitName}” and its sounds will be removed from this device.'**
  String libraryDeleteKitBody(String kitName);

  /// No description provided for @kitEditorTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit kit'**
  String get kitEditorTitle;

  /// No description provided for @kitEditorNewKit.
  ///
  /// In en, this message translates to:
  /// **'New kit'**
  String get kitEditorNewKit;

  /// No description provided for @kitEditorKitName.
  ///
  /// In en, this message translates to:
  /// **'Kit name'**
  String get kitEditorKitName;

  /// No description provided for @kitEditorKitNameHint.
  ///
  /// In en, this message translates to:
  /// **'My kit'**
  String get kitEditorKitNameHint;

  /// No description provided for @kitEditorDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get kitEditorDescription;

  /// No description provided for @kitEditorColor.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get kitEditorColor;

  /// No description provided for @kitEditorPadColor.
  ///
  /// In en, this message translates to:
  /// **'Pad color'**
  String get kitEditorPadColor;

  /// No description provided for @kitEditorPadMode.
  ///
  /// In en, this message translates to:
  /// **'Pad mode'**
  String get kitEditorPadMode;

  /// Pads in the same group stop each other.
  ///
  /// In en, this message translates to:
  /// **'Choke group'**
  String get kitEditorChokeGroup;

  /// No description provided for @kitEditorChokeGroupValue.
  ///
  /// In en, this message translates to:
  /// **'Group {group}'**
  String kitEditorChokeGroupValue(int group);

  /// No description provided for @kitEditorPitch.
  ///
  /// In en, this message translates to:
  /// **'Pitch'**
  String get kitEditorPitch;

  /// Pitch shift in semitones, already signed (e.g. '+3').
  ///
  /// In en, this message translates to:
  /// **'{semitones} st'**
  String kitEditorPitchValue(String semitones);

  /// No description provided for @kitEditorTimeStretch.
  ///
  /// In en, this message translates to:
  /// **'Time stretch'**
  String get kitEditorTimeStretch;

  /// No description provided for @kitEditorVolume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get kitEditorVolume;

  /// No description provided for @kitEditorPan.
  ///
  /// In en, this message translates to:
  /// **'Pan'**
  String get kitEditorPan;

  /// No description provided for @kitEditorTrim.
  ///
  /// In en, this message translates to:
  /// **'Trim'**
  String get kitEditorTrim;

  /// No description provided for @kitEditorFadeIn.
  ///
  /// In en, this message translates to:
  /// **'Fade in'**
  String get kitEditorFadeIn;

  /// No description provided for @kitEditorFadeOut.
  ///
  /// In en, this message translates to:
  /// **'Fade out'**
  String get kitEditorFadeOut;

  /// No description provided for @kitEditorPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get kitEditorPreview;

  /// No description provided for @kitEditorClearPad.
  ///
  /// In en, this message translates to:
  /// **'Clear pad'**
  String get kitEditorClearPad;

  /// No description provided for @kitEditorCopyPad.
  ///
  /// In en, this message translates to:
  /// **'Copy pad'**
  String get kitEditorCopyPad;

  /// No description provided for @kitEditorPastePad.
  ///
  /// In en, this message translates to:
  /// **'Paste pad'**
  String get kitEditorPastePad;

  /// No description provided for @kitEditorSaveKit.
  ///
  /// In en, this message translates to:
  /// **'Save kit'**
  String get kitEditorSaveKit;

  /// No description provided for @kitEditorSaved.
  ///
  /// In en, this message translates to:
  /// **'Kit saved'**
  String get kitEditorSaved;

  /// No description provided for @kitEditorUnsavedTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get kitEditorUnsavedTitle;

  /// No description provided for @kitEditorUnsavedBody.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes to this kit.'**
  String get kitEditorUnsavedBody;

  /// No description provided for @kitEditorDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get kitEditorDiscard;

  /// No description provided for @kitEditorSelectPad.
  ///
  /// In en, this message translates to:
  /// **'Select a pad to load a sound'**
  String get kitEditorSelectPad;

  /// No description provided for @kitEditorMaxLength.
  ///
  /// In en, this message translates to:
  /// **'Sounds are limited to {seconds} seconds'**
  String kitEditorMaxLength(int seconds);

  /// Header of the sound source sheet.
  ///
  /// In en, this message translates to:
  /// **'Load sound'**
  String get loadSoundTitle;

  /// Small overline above a source name.
  ///
  /// In en, this message translates to:
  /// **'Import from'**
  String get loadSoundImportFrom;

  /// Small overline above the microphone source.
  ///
  /// In en, this message translates to:
  /// **'Recording from'**
  String get loadSoundRecordingFrom;

  /// No description provided for @loadSoundSourceSongs.
  ///
  /// In en, this message translates to:
  /// **'Built-in songs'**
  String get loadSoundSourceSongs;

  /// No description provided for @loadSoundSourceMicrophone.
  ///
  /// In en, this message translates to:
  /// **'Microphone'**
  String get loadSoundSourceMicrophone;

  /// No description provided for @loadSoundSourceFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get loadSoundSourceFiles;

  /// No description provided for @loadSoundSourceKits.
  ///
  /// In en, this message translates to:
  /// **'Kits'**
  String get loadSoundSourceKits;

  /// No description provided for @loadSoundSourceRecordings.
  ///
  /// In en, this message translates to:
  /// **'Recordings'**
  String get loadSoundSourceRecordings;

  /// No description provided for @loadSoundHoldToRecord.
  ///
  /// In en, this message translates to:
  /// **'Hold to record'**
  String get loadSoundHoldToRecord;

  /// No description provided for @loadSoundElapsed.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String loadSoundElapsed(int seconds);

  /// No description provided for @recordStart.
  ///
  /// In en, this message translates to:
  /// **'Start recording'**
  String get recordStart;

  /// No description provided for @recordStop.
  ///
  /// In en, this message translates to:
  /// **'Stop recording'**
  String get recordStop;

  /// No description provided for @recordSaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Save recording'**
  String get recordSaveTitle;

  /// No description provided for @recordNameHint.
  ///
  /// In en, this message translates to:
  /// **'Recording name'**
  String get recordNameHint;

  /// Default name of a new recording.
  ///
  /// In en, this message translates to:
  /// **'Track {number}'**
  String recordDefaultName(int number);

  /// No description provided for @recordSaved.
  ///
  /// In en, this message translates to:
  /// **'Recording saved'**
  String get recordSaved;

  /// No description provided for @recordDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard recording?'**
  String get recordDiscardTitle;

  /// No description provided for @worksTitle.
  ///
  /// In en, this message translates to:
  /// **'Recordings'**
  String get worksTitle;

  /// No description provided for @worksEmpty.
  ///
  /// In en, this message translates to:
  /// **'No recordings yet. Tap record to capture your first track.'**
  String get worksEmpty;

  /// No description provided for @worksCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No recordings} =1{1 recording} other{{count} recordings}}'**
  String worksCount(int count);

  /// Date placeholder example.
  ///
  /// In en, this message translates to:
  /// **'Recorded {date}'**
  String worksRecordedOn(DateTime date);

  /// No description provided for @worksExportWav.
  ///
  /// In en, this message translates to:
  /// **'Export WAV'**
  String get worksExportWav;

  /// No description provided for @worksLoop.
  ///
  /// In en, this message translates to:
  /// **'Loop playback'**
  String get worksLoop;

  /// No description provided for @worksShuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get worksShuffle;

  /// No description provided for @worksDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete recording?'**
  String get worksDeleteTitle;

  /// No description provided for @worksDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'“{name}” will be permanently deleted.'**
  String worksDeleteBody(String name);

  /// No description provided for @worksRenameTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename recording'**
  String get worksRenameTitle;

  /// No description provided for @tutorialTitle.
  ///
  /// In en, this message translates to:
  /// **'Tutorial'**
  String get tutorialTitle;

  /// No description provided for @tutorialStep.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String tutorialStep(int current, int total);

  /// No description provided for @tutorialTapHighlighted.
  ///
  /// In en, this message translates to:
  /// **'Tap the highlighted pads'**
  String get tutorialTapHighlighted;

  /// No description provided for @tutorialSwitchBank.
  ///
  /// In en, this message translates to:
  /// **'Switch to bank {bank}'**
  String tutorialSwitchBank(String bank);

  /// No description provided for @tutorialComplete.
  ///
  /// In en, this message translates to:
  /// **'Great job! Tutorial complete'**
  String get tutorialComplete;

  /// No description provided for @tutorialRestart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get tutorialRestart;

  /// No description provided for @tutorialExit.
  ///
  /// In en, this message translates to:
  /// **'Exit tutorial'**
  String get tutorialExit;

  /// No description provided for @tutorialProgress.
  ///
  /// In en, this message translates to:
  /// **'{percent}% complete'**
  String tutorialProgress(int percent);

  /// No description provided for @tutorialUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This kit has no tutorial yet'**
  String get tutorialUnavailable;

  /// No description provided for @tutorialWatchVideo.
  ///
  /// In en, this message translates to:
  /// **'Watch video'**
  String get tutorialWatchVideo;

  /// No description provided for @skinTitle.
  ///
  /// In en, this message translates to:
  /// **'Skins'**
  String get skinTitle;

  /// Built-in skin: glowing gradient pads.
  ///
  /// In en, this message translates to:
  /// **'Neon'**
  String get skinNeon;

  /// Built-in skin: dark pads with coloured outlines.
  ///
  /// In en, this message translates to:
  /// **'Outline'**
  String get skinOutline;

  /// No description provided for @skinLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get skinLight;

  /// No description provided for @skinCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get skinCustom;

  /// No description provided for @skinApply.
  ///
  /// In en, this message translates to:
  /// **'Apply skin'**
  String get skinApply;

  /// No description provided for @skinApplied.
  ///
  /// In en, this message translates to:
  /// **'Skin applied'**
  String get skinApplied;

  /// No description provided for @skinEditorTitle.
  ///
  /// In en, this message translates to:
  /// **'Skin editor'**
  String get skinEditorTitle;

  /// No description provided for @skinEditorNew.
  ///
  /// In en, this message translates to:
  /// **'New skin'**
  String get skinEditorNew;

  /// No description provided for @skinEditorBasedOn.
  ///
  /// In en, this message translates to:
  /// **'Based on {skin}'**
  String skinEditorBasedOn(String skin);

  /// No description provided for @skinEditorNameHint.
  ///
  /// In en, this message translates to:
  /// **'Skin name'**
  String get skinEditorNameHint;

  /// No description provided for @skinEditorGroupSurface.
  ///
  /// In en, this message translates to:
  /// **'Backgrounds'**
  String get skinEditorGroupSurface;

  /// No description provided for @skinEditorGroupText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get skinEditorGroupText;

  /// No description provided for @skinEditorGroupAccent.
  ///
  /// In en, this message translates to:
  /// **'Accent'**
  String get skinEditorGroupAccent;

  /// No description provided for @skinEditorGroupPad.
  ///
  /// In en, this message translates to:
  /// **'Pads'**
  String get skinEditorGroupPad;

  /// No description provided for @skinEditorGroupPalette.
  ///
  /// In en, this message translates to:
  /// **'Pad palette'**
  String get skinEditorGroupPalette;

  /// No description provided for @skinEditorPaletteRole.
  ///
  /// In en, this message translates to:
  /// **'Color {index}'**
  String skinEditorPaletteRole(int index);

  /// No description provided for @skinEditorCore.
  ///
  /// In en, this message translates to:
  /// **'Center'**
  String get skinEditorCore;

  /// No description provided for @skinEditorMid.
  ///
  /// In en, this message translates to:
  /// **'Middle'**
  String get skinEditorMid;

  /// No description provided for @skinEditorEdge.
  ///
  /// In en, this message translates to:
  /// **'Edge'**
  String get skinEditorEdge;

  /// No description provided for @skinEditorGlow.
  ///
  /// In en, this message translates to:
  /// **'Glow'**
  String get skinEditorGlow;

  /// No description provided for @skinEditorCornerRadius.
  ///
  /// In en, this message translates to:
  /// **'Corner radius'**
  String get skinEditorCornerRadius;

  /// No description provided for @skinEditorGlowIntensity.
  ///
  /// In en, this message translates to:
  /// **'Glow intensity'**
  String get skinEditorGlowIntensity;

  /// No description provided for @skinEditorResetToken.
  ///
  /// In en, this message translates to:
  /// **'Reset to default'**
  String get skinEditorResetToken;

  /// No description provided for @skinEditorResetAll.
  ///
  /// In en, this message translates to:
  /// **'Reset all'**
  String get skinEditorResetAll;

  /// No description provided for @skinEditorExport.
  ///
  /// In en, this message translates to:
  /// **'Export skin'**
  String get skinEditorExport;

  /// No description provided for @skinEditorImport.
  ///
  /// In en, this message translates to:
  /// **'Import skin'**
  String get skinEditorImport;

  /// No description provided for @skinEditorImportInvalid.
  ///
  /// In en, this message translates to:
  /// **'This skin file is invalid'**
  String get skinEditorImportInvalid;

  /// No description provided for @skinEditorImportIgnored.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 setting from a newer version was ignored} other{{count} settings from a newer version were ignored}}'**
  String skinEditorImportIgnored(int count);

  /// No description provided for @skinEditorChangeCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No changes} =1{1 change} other{{count} changes}}'**
  String skinEditorChangeCount(int count);

  /// No description provided for @skinEditorDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete skin?'**
  String get skinEditorDeleteTitle;

  /// Name of a built-in pad skin (built-in skin list).
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get skinPresetDefault;

  /// No description provided for @skinPresetNumber.
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get skinPresetNumber;

  /// No description provided for @skinPresetChristmas.
  ///
  /// In en, this message translates to:
  /// **'Christmas'**
  String get skinPresetChristmas;

  /// No description provided for @skinPresetPets.
  ///
  /// In en, this message translates to:
  /// **'Pets'**
  String get skinPresetPets;

  /// No description provided for @skinPresetCover.
  ///
  /// In en, this message translates to:
  /// **'Cover'**
  String get skinPresetCover;

  /// No description provided for @skinPresetBroken.
  ///
  /// In en, this message translates to:
  /// **'Broken'**
  String get skinPresetBroken;

  /// No description provided for @skinPresetMuertos.
  ///
  /// In en, this message translates to:
  /// **'Muertos'**
  String get skinPresetMuertos;

  /// No description provided for @skinPresetCrazy.
  ///
  /// In en, this message translates to:
  /// **'Crazy'**
  String get skinPresetCrazy;

  /// No description provided for @skinPresetLaunchpad.
  ///
  /// In en, this message translates to:
  /// **'Launchpad'**
  String get skinPresetLaunchpad;

  /// No description provided for @skinPresetCrafts.
  ///
  /// In en, this message translates to:
  /// **'Crafts'**
  String get skinPresetCrafts;

  /// No description provided for @skinPresetPolished.
  ///
  /// In en, this message translates to:
  /// **'Polished'**
  String get skinPresetPolished;

  /// No description provided for @skinPresetClean.
  ///
  /// In en, this message translates to:
  /// **'Clean'**
  String get skinPresetClean;

  /// No description provided for @skinPresetCircle.
  ///
  /// In en, this message translates to:
  /// **'Circle'**
  String get skinPresetCircle;

  /// No description provided for @skinPresetSquare.
  ///
  /// In en, this message translates to:
  /// **'Square'**
  String get skinPresetSquare;

  /// No description provided for @skinPresetLgbt.
  ///
  /// In en, this message translates to:
  /// **'Rainbow'**
  String get skinPresetLgbt;

  /// No description provided for @skinPresetHalloween.
  ///
  /// In en, this message translates to:
  /// **'Halloween'**
  String get skinPresetHalloween;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get settingsAudio;

  /// No description provided for @settingsOutputDevice.
  ///
  /// In en, this message translates to:
  /// **'Output device'**
  String get settingsOutputDevice;

  /// No description provided for @settingsInputDevice.
  ///
  /// In en, this message translates to:
  /// **'Input device'**
  String get settingsInputDevice;

  /// No description provided for @settingsBufferSize.
  ///
  /// In en, this message translates to:
  /// **'Buffer size'**
  String get settingsBufferSize;

  /// No description provided for @settingsBufferSizeValue.
  ///
  /// In en, this message translates to:
  /// **'{frames} samples ({ms} ms)'**
  String settingsBufferSizeValue(int frames, double ms);

  /// No description provided for @settingsSampleRate.
  ///
  /// In en, this message translates to:
  /// **'Sample rate'**
  String get settingsSampleRate;

  /// No description provided for @settingsSampleRateValue.
  ///
  /// In en, this message translates to:
  /// **'{rate} Hz'**
  String settingsSampleRateValue(int rate);

  /// No description provided for @settingsLatency.
  ///
  /// In en, this message translates to:
  /// **'Latency'**
  String get settingsLatency;

  /// No description provided for @settingsMeasureLatency.
  ///
  /// In en, this message translates to:
  /// **'Measure latency'**
  String get settingsMeasureLatency;

  /// No description provided for @settingsLatencyValue.
  ///
  /// In en, this message translates to:
  /// **'{ms} ms'**
  String settingsLatencyValue(int ms);

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default ({language})'**
  String settingsLanguageSystem(String language);

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsSkin.
  ///
  /// In en, this message translates to:
  /// **'Skin'**
  String get settingsSkin;

  /// No description provided for @settingsAnimatePads.
  ///
  /// In en, this message translates to:
  /// **'Animate pads'**
  String get settingsAnimatePads;

  /// No description provided for @settingsReduceMotion.
  ///
  /// In en, this message translates to:
  /// **'Reduce motion'**
  String get settingsReduceMotion;

  /// No description provided for @settingsHaptics.
  ///
  /// In en, this message translates to:
  /// **'Haptic feedback'**
  String get settingsHaptics;

  /// No description provided for @settingsKeepScreenOn.
  ///
  /// In en, this message translates to:
  /// **'Keep screen on'**
  String get settingsKeepScreenOn;

  /// No description provided for @settingsMidi.
  ///
  /// In en, this message translates to:
  /// **'MIDI'**
  String get settingsMidi;

  /// No description provided for @settingsMidiDevices.
  ///
  /// In en, this message translates to:
  /// **'MIDI devices'**
  String get settingsMidiDevices;

  /// No description provided for @settingsMidiNone.
  ///
  /// In en, this message translates to:
  /// **'No MIDI devices connected'**
  String get settingsMidiNone;

  /// No description provided for @settingsKeyboardMapping.
  ///
  /// In en, this message translates to:
  /// **'Keyboard mapping'**
  String get settingsKeyboardMapping;

  /// No description provided for @settingsStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get settingsStorage;

  /// size is pre-formatted, e.g. '120 MB'.
  ///
  /// In en, this message translates to:
  /// **'{size} used'**
  String settingsStorageUsed(String size);

  /// No description provided for @settingsClearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear cache'**
  String get settingsClearCache;

  /// No description provided for @settingsCacheCleared.
  ///
  /// In en, this message translates to:
  /// **'Cache cleared'**
  String get settingsCacheCleared;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String settingsVersion(String version);

  /// No description provided for @settingsLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open-source licenses'**
  String get settingsLicenses;

  /// No description provided for @settingsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get settingsPrivacy;

  /// No description provided for @settingsResearchNotice.
  ///
  /// In en, this message translates to:
  /// **'UltraPads is an open-source research project (Apache-2.0).'**
  String get settingsResearchNotice;

  /// No description provided for @hubTitle.
  ///
  /// In en, this message translates to:
  /// **'My devices'**
  String get hubTitle;

  /// No description provided for @hubDescription.
  ///
  /// In en, this message translates to:
  /// **'Sync your library and use your phone as a pad controller over the local network.'**
  String get hubDescription;

  /// No description provided for @hubEnable.
  ///
  /// In en, this message translates to:
  /// **'Run hub on this device'**
  String get hubEnable;

  /// No description provided for @hubRunning.
  ///
  /// In en, this message translates to:
  /// **'Hub running at {address}'**
  String hubRunning(String address);

  /// No description provided for @hubStopped.
  ///
  /// In en, this message translates to:
  /// **'Hub stopped'**
  String get hubStopped;

  /// No description provided for @hubDiscovering.
  ///
  /// In en, this message translates to:
  /// **'Looking for devices…'**
  String get hubDiscovering;

  /// No description provided for @hubNoDevices.
  ///
  /// In en, this message translates to:
  /// **'No devices found on this network'**
  String get hubNoDevices;

  /// No description provided for @hubDeviceOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get hubDeviceOnline;

  /// No description provided for @hubDeviceOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get hubDeviceOffline;

  /// time is a pre-formatted relative time.
  ///
  /// In en, this message translates to:
  /// **'Last seen {time}'**
  String hubDeviceLastSeen(String time);

  /// No description provided for @hubDeviceCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No paired devices} =1{1 paired device} other{{count} paired devices}}'**
  String hubDeviceCount(int count);

  /// No description provided for @pairingNewDevice.
  ///
  /// In en, this message translates to:
  /// **'Pair new device'**
  String get pairingNewDevice;

  /// No description provided for @pairingCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Pairing code'**
  String get pairingCodeTitle;

  /// No description provided for @pairingCodeBody.
  ///
  /// In en, this message translates to:
  /// **'Enter this code on your other device: {code}'**
  String pairingCodeBody(String code);

  /// No description provided for @pairingEnterCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the code shown on your other device'**
  String get pairingEnterCode;

  /// No description provided for @pairingConfirm.
  ///
  /// In en, this message translates to:
  /// **'Pair with {deviceName}?'**
  String pairingConfirm(String deviceName);

  /// No description provided for @pairingSuccess.
  ///
  /// In en, this message translates to:
  /// **'Paired with {deviceName}'**
  String pairingSuccess(String deviceName);

  /// No description provided for @pairingFailed.
  ///
  /// In en, this message translates to:
  /// **'Pairing failed. Check the code and try again.'**
  String get pairingFailed;

  /// No description provided for @pairingExpired.
  ///
  /// In en, this message translates to:
  /// **'The code has expired'**
  String get pairingExpired;

  /// No description provided for @pairingUnpair.
  ///
  /// In en, this message translates to:
  /// **'Unpair'**
  String get pairingUnpair;

  /// No description provided for @pairingUnpairConfirm.
  ///
  /// In en, this message translates to:
  /// **'Unpair {deviceName}? It will stop syncing with this device.'**
  String pairingUnpairConfirm(String deviceName);

  /// No description provided for @pairingOwnDevicesOnly.
  ///
  /// In en, this message translates to:
  /// **'Only pair devices you own.'**
  String get pairingOwnDevicesOnly;

  /// No description provided for @pairingSameNetwork.
  ///
  /// In en, this message translates to:
  /// **'Both devices must be on the same Wi-Fi network.'**
  String get pairingSameNetwork;

  /// No description provided for @hubSyncLibrary.
  ///
  /// In en, this message translates to:
  /// **'Sync library'**
  String get hubSyncLibrary;

  /// No description provided for @hubSyncProgress.
  ///
  /// In en, this message translates to:
  /// **'Syncing {done} of {total}…'**
  String hubSyncProgress(int done, int total);

  /// No description provided for @hubSyncDone.
  ///
  /// In en, this message translates to:
  /// **'Library is up to date'**
  String get hubSyncDone;

  /// No description provided for @hubSyncConflicts.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 conflict needs attention} other{{count} conflicts need attention}}'**
  String hubSyncConflicts(int count);

  /// No description provided for @hubUseAsController.
  ///
  /// In en, this message translates to:
  /// **'Use as controller'**
  String get hubUseAsController;

  /// No description provided for @hubControlling.
  ///
  /// In en, this message translates to:
  /// **'Controlling {deviceName}'**
  String hubControlling(String deviceName);

  /// No description provided for @hubDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected from {deviceName}'**
  String hubDisconnected(String deviceName);

  /// No description provided for @hubRoundTrip.
  ///
  /// In en, this message translates to:
  /// **'Round trip {ms} ms'**
  String hubRoundTrip(int ms);

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorGeneric;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'No network connection'**
  String get errorNetwork;

  /// No description provided for @errorTimeout.
  ///
  /// In en, this message translates to:
  /// **'The request timed out'**
  String get errorTimeout;

  /// No description provided for @errorDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed. Check your connection and try again.'**
  String get errorDownloadFailed;

  /// No description provided for @errorKitCorrupt.
  ///
  /// In en, this message translates to:
  /// **'This kit is damaged and can\'t be loaded'**
  String get errorKitCorrupt;

  /// No description provided for @errorKitNotFound.
  ///
  /// In en, this message translates to:
  /// **'Kit not found'**
  String get errorKitNotFound;

  /// No description provided for @errorAudioDevice.
  ///
  /// In en, this message translates to:
  /// **'Audio device unavailable'**
  String get errorAudioDevice;

  /// No description provided for @errorAudioEngine.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start the audio engine ({code})'**
  String errorAudioEngine(String code);

  /// No description provided for @errorStorageFull.
  ///
  /// In en, this message translates to:
  /// **'Not enough storage space'**
  String get errorStorageFull;

  /// No description provided for @errorFileRead.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read “{fileName}”'**
  String errorFileRead(String fileName);

  /// No description provided for @errorFileWrite.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save “{fileName}”'**
  String errorFileWrite(String fileName);

  /// No description provided for @errorUnsupportedFormat.
  ///
  /// In en, this message translates to:
  /// **'This file format isn\'t supported'**
  String get errorUnsupportedFormat;

  /// No description provided for @errorRecordingFailed.
  ///
  /// In en, this message translates to:
  /// **'Recording failed'**
  String get errorRecordingFailed;

  /// No description provided for @errorPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Permission denied'**
  String get errorPermissionDenied;

  /// No description provided for @errorDeviceUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach {deviceName}'**
  String errorDeviceUnreachable(String deviceName);

  /// No description provided for @errorVersionMismatch.
  ///
  /// In en, this message translates to:
  /// **'{deviceName} runs an incompatible version'**
  String errorVersionMismatch(String deviceName);

  /// No description provided for @errorNameEmpty.
  ///
  /// In en, this message translates to:
  /// **'Name can\'t be empty'**
  String get errorNameEmpty;

  /// No description provided for @errorNameTooLong.
  ///
  /// In en, this message translates to:
  /// **'{max, plural, =1{Name must be at most 1 character} other{Name must be at most {max} characters}}'**
  String errorNameTooLong(int max);

  /// No description provided for @errorNameTaken.
  ///
  /// In en, this message translates to:
  /// **'That name is already in use'**
  String get errorNameTaken;

  /// No description provided for @permissionMicrophoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Microphone access'**
  String get permissionMicrophoneTitle;

  /// No description provided for @permissionMicrophoneBody.
  ///
  /// In en, this message translates to:
  /// **'UltraPads uses the microphone to record sounds into your pads. Recordings stay on your device.'**
  String get permissionMicrophoneBody;

  /// No description provided for @permissionStorageTitle.
  ///
  /// In en, this message translates to:
  /// **'File access'**
  String get permissionStorageTitle;

  /// No description provided for @permissionStorageBody.
  ///
  /// In en, this message translates to:
  /// **'Allow file access to import audio and export your recordings.'**
  String get permissionStorageBody;

  /// No description provided for @permissionLocalNetworkTitle.
  ///
  /// In en, this message translates to:
  /// **'Local network'**
  String get permissionLocalNetworkTitle;

  /// No description provided for @permissionLocalNetworkBody.
  ///
  /// In en, this message translates to:
  /// **'Used only to find and connect your own devices on this Wi-Fi.'**
  String get permissionLocalNetworkBody;

  /// No description provided for @permissionBluetoothTitle.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth MIDI'**
  String get permissionBluetoothTitle;

  /// No description provided for @permissionBluetoothBody.
  ///
  /// In en, this message translates to:
  /// **'Allow Bluetooth to connect wireless MIDI controllers.'**
  String get permissionBluetoothBody;

  /// No description provided for @permissionNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get permissionNotificationsTitle;

  /// No description provided for @permissionNotificationsBody.
  ///
  /// In en, this message translates to:
  /// **'Get notified when a sync or export finishes.'**
  String get permissionNotificationsBody;

  /// No description provided for @permissionAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get permissionAllow;

  /// No description provided for @permissionOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get permissionOpenSettings;

  /// No description provided for @permissionDeniedForever.
  ///
  /// In en, this message translates to:
  /// **'Permission was denied. You can enable it in system settings.'**
  String get permissionDeniedForever;

  /// No description provided for @shareKitMessage.
  ///
  /// In en, this message translates to:
  /// **'Play my kit “{kitName}” on UltraPads'**
  String shareKitMessage(String kitName);

  /// No description provided for @shareRecordingMessage.
  ///
  /// In en, this message translates to:
  /// **'Listen to “{name}”, made with UltraPads'**
  String shareRecordingMessage(String name);

  /// No description provided for @shareLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get shareLinkCopied;

  /// No description provided for @a11yOpenMenu.
  ///
  /// In en, this message translates to:
  /// **'Open menu'**
  String get a11yOpenMenu;

  /// No description provided for @a11yCloseSheet.
  ///
  /// In en, this message translates to:
  /// **'Close panel'**
  String get a11yCloseSheet;

  /// No description provided for @a11yKitCover.
  ///
  /// In en, this message translates to:
  /// **'Cover of {kitName}'**
  String a11yKitCover(String kitName);

  /// No description provided for @a11yWaveform.
  ///
  /// In en, this message translates to:
  /// **'Waveform of {name}'**
  String a11yWaveform(String name);

  /// No description provided for @a11yProgress.
  ///
  /// In en, this message translates to:
  /// **'{percent} percent'**
  String a11yProgress(int percent);

  /// No description provided for @timeJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get timeJustNow;

  /// No description provided for @timeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute ago} other{{count} minutes ago}}'**
  String timeMinutesAgo(int count);

  /// No description provided for @timeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour ago} other{{count} hours ago}}'**
  String timeHoursAgo(int count);

  /// No description provided for @timeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Yesterday} other{{count} days ago}}'**
  String timeDaysAgo(int count);

  /// No description provided for @unitSeconds.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 second} other{{count} seconds}}'**
  String unitSeconds(int count);

  /// No description provided for @onboardingMakeMusicTitle.
  ///
  /// In en, this message translates to:
  /// **'Make your own music!'**
  String get onboardingMakeMusicTitle;

  /// No description provided for @onboardingRhythmsTitle.
  ///
  /// In en, this message translates to:
  /// **'Enjoy the best rhythms'**
  String get onboardingRhythmsTitle;

  /// No description provided for @onboardingLoopsTitle.
  ///
  /// In en, this message translates to:
  /// **'Discover DJ loops & beats!'**
  String get onboardingLoopsTitle;

  /// No description provided for @onboardingStyleTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your style'**
  String get onboardingStyleTitle;

  /// No description provided for @onboardingShareTitle.
  ///
  /// In en, this message translates to:
  /// **'Share your music'**
  String get onboardingShareTitle;

  /// No description provided for @onboardingStart.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get onboardingStart;

  /// ICU select example: how the user wants to play.
  ///
  /// In en, this message translates to:
  /// **'{choice, select, solo{Play solo} jam{Jam with friends} other{Just exploring}}'**
  String onboardingPlayStyle(String choice);

  /// Compact speed pill on the perform screen (e.g. 1.0×).
  ///
  /// In en, this message translates to:
  /// **'{value}×'**
  String performSpeedValue(double value);

  /// Toggle: use the Lottie pad press animation from the private asset pack when private assets are installed.
  ///
  /// In en, this message translates to:
  /// **'Classic pad animation'**
  String get settingsClassicPads;

  /// About section; name is 'ffi' or 'mock'.
  ///
  /// In en, this message translates to:
  /// **'Audio engine: {name}'**
  String settingsEngineBackend(String name);

  /// Shown when the FFI engine failed to load and the mock engine is used.
  ///
  /// In en, this message translates to:
  /// **'Native audio engine unavailable — running in demo mode'**
  String get settingsEngineFallback;

  /// A feature whose FFI function is not implemented yet.
  ///
  /// In en, this message translates to:
  /// **'The audio engine doesn\'t support this yet'**
  String get errorEngineUnsupported;

  /// Title of the sample list after picking a source kit.
  ///
  /// In en, this message translates to:
  /// **'Choose a sound'**
  String get loadSoundPickSample;

  /// Section header for the local hub server.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get hubThisDevice;

  /// Section header for discovered devices.
  ///
  /// In en, this message translates to:
  /// **'Nearby devices'**
  String get hubNearbyDevices;

  /// About: whether private reference assets are installed.
  ///
  /// In en, this message translates to:
  /// **'Private asset pack'**
  String get settingsPrivateAssets;

  /// Skip the onboarding pages.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// Tutorial entry button on the perform screen ('LEARN TO PLAY').
  ///
  /// In en, this message translates to:
  /// **'Learn to play'**
  String get performLearnToPlay;

  /// Collapse the expanded tool row on the perform screen.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get performBackToTools;

  /// Tutorial speed option 1.0×.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get performSpeedNormal;

  /// Tutorial speed option 0.7×.
  ///
  /// In en, this message translates to:
  /// **'Slow'**
  String get performSpeedSlow;

  /// Tutorial speed option 0.5×.
  ///
  /// In en, this message translates to:
  /// **'Very slow'**
  String get performSpeedVerySlow;

  /// Timing judgement: pressed when the pad was full.
  ///
  /// In en, this message translates to:
  /// **'Perfect'**
  String get tutorialPerfect;

  /// Timing judgement: pressed before the pad was full.
  ///
  /// In en, this message translates to:
  /// **'Too fast'**
  String get tutorialTooFast;

  /// Timing judgement: pressed after the pad was full.
  ///
  /// In en, this message translates to:
  /// **'Too slow'**
  String get tutorialTooSlow;

  /// Timing judgement: the step passed without a press.
  ///
  /// In en, this message translates to:
  /// **'Miss'**
  String get tutorialMiss;

  /// First tutorial hint.
  ///
  /// In en, this message translates to:
  /// **'Press the pad when it\'s fully filled'**
  String get tutorialPressWhenFull;

  /// Start / resume the tutorial timeline.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get tutorialPlayDemo;

  /// Library tab: featured feed.
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get navFeed;

  /// Open the full category list.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get librarySeeAll;

  /// Feed section: artists.
  ///
  /// In en, this message translates to:
  /// **'Artists'**
  String get libraryArtists;

  /// Feed section: recommended kits.
  ///
  /// In en, this message translates to:
  /// **'Recommended for you'**
  String get libraryRecommended;

  /// Import kit page: open the imported kit.
  ///
  /// In en, this message translates to:
  /// **'Open kit'**
  String get libraryOpenKit;

  /// Kit editor tab: pad properties.
  ///
  /// In en, this message translates to:
  /// **'Edit pad'**
  String get kitEditorEditPad;

  /// Kit editor: waveform trim view.
  ///
  /// In en, this message translates to:
  /// **'Edit file'**
  String get kitEditorEditFile;

  /// Kit editor: clone the selected pad to another pad.
  ///
  /// In en, this message translates to:
  /// **'Clone'**
  String get kitEditorClone;

  /// Kit editor: choke group stepper.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get kitEditorGroup;

  /// Kit editor: loop switch.
  ///
  /// In en, this message translates to:
  /// **'Loop'**
  String get kitEditorLoop;

  /// Confirm replacing a pad that already has audio.
  ///
  /// In en, this message translates to:
  /// **'Replace this sound?'**
  String get kitEditorReplaceTitle;

  /// Save recording page: save then open the share sheet.
  ///
  /// In en, this message translates to:
  /// **'Save and share'**
  String get recordSaveAndShare;

  /// Onboarding: next page.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// Category preference page body.
  ///
  /// In en, this message translates to:
  /// **'Pick the styles you like and we\'ll start you off with the right kits'**
  String get onboardingChooseStyleBody;

  /// Settings section for developer tools.
  ///
  /// In en, this message translates to:
  /// **'Developer'**
  String get settingsDeveloper;

  /// In-app Storybook-style gallery of tokens and components.
  ///
  /// In en, this message translates to:
  /// **'Design gallery'**
  String get settingsDesignGallery;

  /// Gallery tab: token browser.
  ///
  /// In en, this message translates to:
  /// **'Tokens'**
  String get settingsGalleryTokens;

  /// Gallery tab: component states.
  ///
  /// In en, this message translates to:
  /// **'Components'**
  String get settingsGalleryComponents;

  /// Gallery tab: theme and skin presets.
  ///
  /// In en, this message translates to:
  /// **'Themes & skins'**
  String get settingsGallerySkins;

  /// Gallery tab: motion demos.
  ///
  /// In en, this message translates to:
  /// **'Motion'**
  String get settingsGalleryMotion;

  /// Token browser: primitive colour group.
  ///
  /// In en, this message translates to:
  /// **'Primitive colors'**
  String get settingsGalleryPrimitive;

  /// Token browser: semantic colours of the current theme.
  ///
  /// In en, this message translates to:
  /// **'Semantic colors'**
  String get settingsGallerySemantic;

  /// Token browser: radius scale.
  ///
  /// In en, this message translates to:
  /// **'Corner radius'**
  String get settingsGalleryRadii;

  /// Token browser: spacing scale.
  ///
  /// In en, this message translates to:
  /// **'Spacing'**
  String get settingsGallerySpacing;

  /// Token browser: text roles.
  ///
  /// In en, this message translates to:
  /// **'Typography'**
  String get settingsGalleryTypography;

  /// Token browser: glow recipes.
  ///
  /// In en, this message translates to:
  /// **'Glow & shadow'**
  String get settingsGalleryGlow;

  /// Token browser: motion durations and easing curves.
  ///
  /// In en, this message translates to:
  /// **'Durations & curves'**
  String get settingsGalleryDurations;

  /// Replay a motion demo.
  ///
  /// In en, this message translates to:
  /// **'Replay'**
  String get settingsGalleryReplay;

  /// Component state variants heading.
  ///
  /// In en, this message translates to:
  /// **'States'**
  String get settingsGalleryStates;

  /// Component state: disabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get settingsGalleryDisabled;

  /// Component state: pressed.
  ///
  /// In en, this message translates to:
  /// **'Pressed'**
  String get settingsGalleryPressed;

  /// No description provided for @hubLocalAddresses.
  ///
  /// In en, this message translates to:
  /// **'Addresses of this device'**
  String get hubLocalAddresses;

  /// No description provided for @hubAddressHint.
  ///
  /// In en, this message translates to:
  /// **'If your phone can\'t find this device, enter one of these addresses on it.'**
  String get hubAddressHint;

  /// No description provided for @pairingNewCode.
  ///
  /// In en, this message translates to:
  /// **'New code'**
  String get pairingNewCode;

  /// No description provided for @pairingValidUntil.
  ///
  /// In en, this message translates to:
  /// **'Valid until {time}, up to 5 attempts'**
  String pairingValidUntil(String time);

  /// No description provided for @hubTrustedDevices.
  ///
  /// In en, this message translates to:
  /// **'Trusted devices'**
  String get hubTrustedDevices;

  /// No description provided for @hubRevoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get hubRevoke;

  /// No description provided for @hubRevokeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Revoke {deviceName}? It will no longer be able to sync with or control this device.'**
  String hubRevokeConfirm(String deviceName);

  /// No description provided for @hubRemoteControlling.
  ///
  /// In en, this message translates to:
  /// **'{deviceName} is controlling this device'**
  String hubRemoteControlling(String deviceName);

  /// No description provided for @hubManualAddress.
  ///
  /// In en, this message translates to:
  /// **'Enter address manually'**
  String get hubManualAddress;

  /// No description provided for @hubManualAddressHint.
  ///
  /// In en, this message translates to:
  /// **'IP or IP:port, e.g. 192.168.1.10:47100'**
  String get hubManualAddressHint;

  /// No description provided for @hubConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get hubConnect;

  /// No description provided for @hubProbeFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach {address}'**
  String hubProbeFailed(String address);

  /// No description provided for @hubLocalEcho.
  ///
  /// In en, this message translates to:
  /// **'Also play on this device'**
  String get hubLocalEcho;

  /// No description provided for @hubLocalEchoHint.
  ///
  /// In en, this message translates to:
  /// **'By default only the controlled device plays'**
  String get hubLocalEchoHint;

  /// No description provided for @hubStopControlling.
  ///
  /// In en, this message translates to:
  /// **'Stop controlling'**
  String get hubStopControlling;

  /// No description provided for @hubSyncFinished.
  ///
  /// In en, this message translates to:
  /// **'Sync finished: {down} downloaded, {up} uploaded'**
  String hubSyncFinished(int down, int up);

  /// No description provided for @hubSyncStarting.
  ///
  /// In en, this message translates to:
  /// **'Preparing sync…'**
  String get hubSyncStarting;

  /// No description provided for @hubDeviceId.
  ///
  /// In en, this message translates to:
  /// **'Device ID: {id}'**
  String hubDeviceId(String id);

  /// No description provided for @hubErrorOp.
  ///
  /// In en, this message translates to:
  /// **'Hub operation failed ({op})'**
  String hubErrorOp(String op);

  /// No description provided for @settingsAudioStatus.
  ///
  /// In en, this message translates to:
  /// **'Audio status'**
  String get settingsAudioStatus;

  /// No description provided for @settingsAudioStatusValue.
  ///
  /// In en, this message translates to:
  /// **'{host} · {device} · {channels} ch {format}'**
  String settingsAudioStatusValue(
    String host,
    String device,
    int channels,
    String format,
  );

  /// No description provided for @settingsAudioStopped.
  ///
  /// In en, this message translates to:
  /// **'Audio output is not running'**
  String get settingsAudioStopped;

  /// Video platform shown on the perform-page video tutorial button (BiliBili in China, YouTube elsewhere).
  ///
  /// In en, this message translates to:
  /// **'YouTube'**
  String get performVideoPlatform;

  /// No description provided for @performVideoOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the video link'**
  String get performVideoOpenFailed;

  /// No description provided for @tutorialFirstGuideStep.
  ///
  /// In en, this message translates to:
  /// **'STEP {step}/{total}'**
  String tutorialFirstGuideStep(int step, int total);

  /// No description provided for @tutorialFirstGuidePad.
  ///
  /// In en, this message translates to:
  /// **'Tap a pad to start your first beat!'**
  String get tutorialFirstGuidePad;

  /// No description provided for @tutorialFirstGuideLearn.
  ///
  /// In en, this message translates to:
  /// **'Tap LEARN TO PLAY to learn the whole song step by step.'**
  String get tutorialFirstGuideLearn;

  /// No description provided for @tutorialFirstGuideMore.
  ///
  /// In en, this message translates to:
  /// **'Recording, skins, kit editing and settings live under ⋮.'**
  String get tutorialFirstGuideMore;

  /// No description provided for @tutorialFirstGuideSongs.
  ///
  /// In en, this message translates to:
  /// **'Tap SONGS to open the library and pick more kits.'**
  String get tutorialFirstGuideSongs;

  /// No description provided for @tutorialFirstGuideDone.
  ///
  /// In en, this message translates to:
  /// **'LET\'S PLAY'**
  String get tutorialFirstGuideDone;

  /// No description provided for @settingsReplayGuide.
  ///
  /// In en, this message translates to:
  /// **'Show the first-run guide again'**
  String get settingsReplayGuide;

  /// No description provided for @settingsReplayGuideDone.
  ///
  /// In en, this message translates to:
  /// **'The guide will show on the perform screen'**
  String get settingsReplayGuideDone;

  /// No description provided for @settingsBufferSizeSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsBufferSizeSystem;

  /// No description provided for @settingsUpdateTitle.
  ///
  /// In en, this message translates to:
  /// **'Software update'**
  String get settingsUpdateTitle;

  /// No description provided for @settingsUpdateAutoCheck.
  ///
  /// In en, this message translates to:
  /// **'Check for updates automatically'**
  String get settingsUpdateAutoCheck;

  /// No description provided for @settingsUpdateAutoCheckHint.
  ///
  /// In en, this message translates to:
  /// **'Asks the update server once after launch; sends nothing about you or this device.'**
  String get settingsUpdateAutoCheckHint;

  /// No description provided for @settingsUpdateCheckNow.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get settingsUpdateCheckNow;

  /// No description provided for @settingsUpdateChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking for updates…'**
  String get settingsUpdateChecking;

  /// No description provided for @settingsUpdateUpToDate.
  ///
  /// In en, this message translates to:
  /// **'UltraPads is up to date'**
  String get settingsUpdateUpToDate;

  /// No description provided for @settingsUpdateCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t check for updates'**
  String get settingsUpdateCheckFailed;

  /// No description provided for @settingsUpdateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Version {version} is available'**
  String settingsUpdateAvailable(String version);

  /// No description provided for @settingsUpdateAvailableToast.
  ///
  /// In en, this message translates to:
  /// **'UltraPads {version} is available — update it in Settings'**
  String settingsUpdateAvailableToast(String version);

  /// No description provided for @settingsUpdateNow.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get settingsUpdateNow;

  /// No description provided for @settingsUpdateDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading… {percent}%'**
  String settingsUpdateDownloading(int percent);

  /// No description provided for @settingsUpdateDownloadingGithub.
  ///
  /// In en, this message translates to:
  /// **'Downloading from GitHub… {percent}%'**
  String settingsUpdateDownloadingGithub(int percent);

  /// No description provided for @settingsUpdateRestart.
  ///
  /// In en, this message translates to:
  /// **'Restart to finish'**
  String get settingsUpdateRestart;

  /// No description provided for @settingsUpdateInstall.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get settingsUpdateInstall;

  /// No description provided for @settingsUpdateInstallPermission.
  ///
  /// In en, this message translates to:
  /// **'Allow UltraPads to install apps in the next screen, then tap Install again.'**
  String get settingsUpdateInstallPermission;

  /// No description provided for @settingsUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Update failed'**
  String get settingsUpdateFailed;

  /// No description provided for @settingsUpdateReleaseNotes.
  ///
  /// In en, this message translates to:
  /// **'What\'s new'**
  String get settingsUpdateReleaseNotes;

  /// No description provided for @settingsUpdateDownloadPage.
  ///
  /// In en, this message translates to:
  /// **'Download page'**
  String get settingsUpdateDownloadPage;

  /// No description provided for @settingsUpdateManualHint.
  ///
  /// In en, this message translates to:
  /// **'This copy wasn\'t installed with the install script, so it can\'t update itself. Get the new version from the download page.'**
  String get settingsUpdateManualHint;

  /// No description provided for @performSoundGroup.
  ///
  /// In en, this message translates to:
  /// **'Sound group {name}'**
  String performSoundGroup(String name);

  /// No description provided for @performFirstGuideGroups.
  ///
  /// In en, this message translates to:
  /// **'Each song can have several sound groups — tap A, B… to switch. Sounds already playing keep going.'**
  String get performFirstGuideGroups;

  /// No description provided for @kitEditorGroups.
  ///
  /// In en, this message translates to:
  /// **'Sound groups'**
  String get kitEditorGroups;

  /// No description provided for @kitEditorAddGroup.
  ///
  /// In en, this message translates to:
  /// **'Add a sound group'**
  String get kitEditorAddGroup;

  /// No description provided for @kitEditorMoveGroupLeft.
  ///
  /// In en, this message translates to:
  /// **'Move group {name} left'**
  String kitEditorMoveGroupLeft(String name);

  /// No description provided for @kitEditorMoveGroupRight.
  ///
  /// In en, this message translates to:
  /// **'Move group {name} right'**
  String kitEditorMoveGroupRight(String name);

  /// No description provided for @kitEditorDeleteGroup.
  ///
  /// In en, this message translates to:
  /// **'Delete group {name}'**
  String kitEditorDeleteGroup(String name);

  /// No description provided for @kitEditorDeleteGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete sound group {name}?'**
  String kitEditorDeleteGroupTitle(String name);

  /// No description provided for @kitEditorDeleteGroupBody.
  ///
  /// In en, this message translates to:
  /// **'Its {count} pads are removed and the groups after it move up.'**
  String kitEditorDeleteGroupBody(int count);

  /// No description provided for @settingsOutputDeviceSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow the system'**
  String get settingsOutputDeviceSystem;

  /// No description provided for @settingsOutputDeviceFallback.
  ///
  /// In en, this message translates to:
  /// **'{name} is unavailable — using the system output'**
  String settingsOutputDeviceFallback(String name);

  /// No description provided for @navCatalog.
  ///
  /// In en, this message translates to:
  /// **'Official'**
  String get navCatalog;

  /// No description provided for @libraryCatalogSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search official songs'**
  String get libraryCatalogSearchHint;

  /// No description provided for @libraryCatalogFilters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get libraryCatalogFilters;

  /// No description provided for @libraryCatalogFilterLicense.
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get libraryCatalogFilterLicense;

  /// No description provided for @libraryCatalogFilterGenre.
  ///
  /// In en, this message translates to:
  /// **'Genre'**
  String get libraryCatalogFilterGenre;

  /// No description provided for @libraryCatalogFilterBpm.
  ///
  /// In en, this message translates to:
  /// **'Tempo'**
  String get libraryCatalogFilterBpm;

  /// No description provided for @libraryCatalogBpmRange.
  ///
  /// In en, this message translates to:
  /// **'{min}–{max} BPM'**
  String libraryCatalogBpmRange(int min, int max);

  /// No description provided for @libraryCatalogBpmAny.
  ///
  /// In en, this message translates to:
  /// **'Any tempo'**
  String get libraryCatalogBpmAny;

  /// No description provided for @libraryCatalogSortNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get libraryCatalogSortNewest;

  /// No description provided for @libraryCatalogSortBpm.
  ///
  /// In en, this message translates to:
  /// **'BPM'**
  String get libraryCatalogSortBpm;

  /// No description provided for @libraryCatalogSortTitle.
  ///
  /// In en, this message translates to:
  /// **'A–Z'**
  String get libraryCatalogSortTitle;

  /// No description provided for @libraryCatalogClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get libraryCatalogClearFilters;

  /// No description provided for @libraryCatalogFavoritesOnly.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get libraryCatalogFavoritesOnly;

  /// No description provided for @libraryCatalogRecent.
  ///
  /// In en, this message translates to:
  /// **'Recently played'**
  String get libraryCatalogRecent;

  /// No description provided for @libraryCatalogTotal.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No songs} =1{1 song} other{{count} songs}}'**
  String libraryCatalogTotal(int count);

  /// No description provided for @libraryCatalogEmpty.
  ///
  /// In en, this message translates to:
  /// **'No songs match these filters.'**
  String get libraryCatalogEmpty;

  /// No description provided for @libraryCatalogEmptyFavorites.
  ///
  /// In en, this message translates to:
  /// **'Tap the heart on a song to keep it here.'**
  String get libraryCatalogEmptyFavorites;

  /// No description provided for @libraryCatalogLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t reach the official catalog.'**
  String get libraryCatalogLoadFailed;

  /// No description provided for @libraryCatalogLoadFailedOffline.
  ///
  /// In en, this message translates to:
  /// **'You’re offline. Check your connection and try again.'**
  String get libraryCatalogLoadFailedOffline;

  /// No description provided for @libraryCatalogDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get libraryCatalogDownload;

  /// No description provided for @libraryCatalogDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get libraryCatalogDownloaded;

  /// No description provided for @libraryCatalogUpdateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get libraryCatalogUpdateAvailable;

  /// No description provided for @libraryCatalogPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get libraryCatalogPlay;

  /// No description provided for @libraryCatalogDownloadingPercent.
  ///
  /// In en, this message translates to:
  /// **'Downloading {percent}%'**
  String libraryCatalogDownloadingPercent(int percent);

  /// No description provided for @libraryCatalogDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed. Try again.'**
  String get libraryCatalogDownloadFailed;

  /// No description provided for @libraryCatalogDownloadCorrupt.
  ///
  /// In en, this message translates to:
  /// **'The file didn’t pass verification. Try again.'**
  String get libraryCatalogDownloadCorrupt;

  /// No description provided for @libraryCatalogDownloadNotFound.
  ///
  /// In en, this message translates to:
  /// **'This song is no longer available.'**
  String get libraryCatalogDownloadNotFound;

  /// No description provided for @libraryCatalogImportedToast.
  ///
  /// In en, this message translates to:
  /// **'{name} is ready to play'**
  String libraryCatalogImportedToast(String name);

  /// No description provided for @libraryCatalogAddFavorite.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get libraryCatalogAddFavorite;

  /// No description provided for @libraryCatalogRemoveFavorite.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get libraryCatalogRemoveFavorite;

  /// No description provided for @libraryCatalogByArtist.
  ///
  /// In en, this message translates to:
  /// **'by {artist}'**
  String libraryCatalogByArtist(String artist);

  /// No description provided for @libraryCatalogDetailCredits.
  ///
  /// In en, this message translates to:
  /// **'Credits'**
  String get libraryCatalogDetailCredits;

  /// No description provided for @libraryCatalogDetailLicense.
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get libraryCatalogDetailLicense;

  /// No description provided for @libraryCatalogDetailSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get libraryCatalogDetailSource;

  /// No description provided for @libraryCatalogDetailOpenSource.
  ///
  /// In en, this message translates to:
  /// **'Open source page'**
  String get libraryCatalogDetailOpenSource;

  /// No description provided for @libraryCatalogDetailOpenLicense.
  ///
  /// In en, this message translates to:
  /// **'Read the license'**
  String get libraryCatalogDetailOpenLicense;

  /// No description provided for @libraryCatalogDetailGroups.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 bank} other{{count} banks}}'**
  String libraryCatalogDetailGroups(int count);

  /// No description provided for @libraryCatalogDetailPads.
  ///
  /// In en, this message translates to:
  /// **'{count} pads'**
  String libraryCatalogDetailPads(int count);

  /// No description provided for @libraryCatalogDetailLoop.
  ///
  /// In en, this message translates to:
  /// **'{secs}s loop'**
  String libraryCatalogDetailLoop(String secs);

  /// No description provided for @libraryCatalogDetailSizeMb.
  ///
  /// In en, this message translates to:
  /// **'{mb} MB'**
  String libraryCatalogDetailSizeMb(String mb);

  /// No description provided for @libraryCatalogOriginAlbum.
  ///
  /// In en, this message translates to:
  /// **'Multitrack album'**
  String get libraryCatalogOriginAlbum;

  /// No description provided for @libraryCatalogOriginOnline.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get libraryCatalogOriginOnline;

  /// No description provided for @libraryCatalogOriginSynth.
  ///
  /// In en, this message translates to:
  /// **'Original synthesis'**
  String get libraryCatalogOriginSynth;

  /// No description provided for @libraryCatalogOriginUgc.
  ///
  /// In en, this message translates to:
  /// **'Community upload'**
  String get libraryCatalogOriginUgc;

  /// No description provided for @libraryCatalogNotFound.
  ///
  /// In en, this message translates to:
  /// **'This song isn’t in the catalog anymore.'**
  String get libraryCatalogNotFound;

  /// No description provided for @libraryLicenseCc0Hint.
  ///
  /// In en, this message translates to:
  /// **'CC0: public domain. Free to use, no credit needed.'**
  String get libraryLicenseCc0Hint;

  /// No description provided for @libraryLicensePdHint.
  ///
  /// In en, this message translates to:
  /// **'Public domain: free to use, no credit needed.'**
  String get libraryLicensePdHint;

  /// No description provided for @libraryLicenseByHint.
  ///
  /// In en, this message translates to:
  /// **'Attribution: credit the creator when you share or publish.'**
  String get libraryLicenseByHint;

  /// No description provided for @libraryLicenseSaHint.
  ///
  /// In en, this message translates to:
  /// **'Share-alike: works built on this must use the same license.'**
  String get libraryLicenseSaHint;

  /// No description provided for @libraryLicenseNcHint.
  ///
  /// In en, this message translates to:
  /// **'Non-commercial: not for commercial use.'**
  String get libraryLicenseNcHint;

  /// No description provided for @settingsAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccountTitle;

  /// No description provided for @settingsAccountSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get settingsAccountSignIn;

  /// No description provided for @settingsAccountSignInHint.
  ///
  /// In en, this message translates to:
  /// **'Keep favorites and recently played in sync across your devices.'**
  String get settingsAccountSignInHint;

  /// No description provided for @settingsAccountSigningIn.
  ///
  /// In en, this message translates to:
  /// **'Finish signing in in your browser…'**
  String get settingsAccountSigningIn;

  /// No description provided for @settingsAccountSignInCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel sign-in'**
  String get settingsAccountSignInCancel;

  /// No description provided for @settingsAccountSignedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {account}'**
  String settingsAccountSignedInAs(String account);

  /// No description provided for @settingsAccountSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get settingsAccountSignOut;

  /// No description provided for @settingsAccountManage.
  ///
  /// In en, this message translates to:
  /// **'Manage account'**
  String get settingsAccountManage;

  /// No description provided for @settingsAccountSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign-in didn’t complete. Try again.'**
  String get settingsAccountSignInFailed;

  /// No description provided for @settingsAccountNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Sign-in isn’t available in this build.'**
  String get settingsAccountNotConfigured;

  /// No description provided for @settingsAccountSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get settingsAccountSyncing;

  /// No description provided for @settingsAccountPendingSync.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 change waiting to sync} other{{count} changes waiting to sync}}'**
  String settingsAccountPendingSync(int count);

  /// No description provided for @settingsAccountSignedOutToast.
  ///
  /// In en, this message translates to:
  /// **'Signed out'**
  String get settingsAccountSignedOutToast;

  /// No description provided for @settingsAccountSignedInToast.
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get settingsAccountSignedInToast;

  /// No description provided for @settingsAccountLoopbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get settingsAccountLoopbackTitle;

  /// No description provided for @settingsAccountLoopbackBody.
  ///
  /// In en, this message translates to:
  /// **'You can close this tab and go back to UltraPads.'**
  String get settingsAccountLoopbackBody;

  /// No description provided for @shareExportCreditsTitle.
  ///
  /// In en, this message translates to:
  /// **'This recording uses licensed material'**
  String get shareExportCreditsTitle;

  /// No description provided for @shareExportCreditsNc.
  ///
  /// In en, this message translates to:
  /// **'Non-commercial use only.'**
  String get shareExportCreditsNc;

  /// No description provided for @shareExportCreditsSa.
  ///
  /// In en, this message translates to:
  /// **'Share your work under the same license.'**
  String get shareExportCreditsSa;

  /// No description provided for @shareExportCreditsShareText.
  ///
  /// In en, this message translates to:
  /// **'Credits:\n{credits}'**
  String shareExportCreditsShareText(String credits);
}

class _UpL10nDelegate extends LocalizationsDelegate<UpL10n> {
  const _UpL10nDelegate();

  @override
  Future<UpL10n> load(Locale locale) {
    return SynchronousFuture<UpL10n>(lookupUpL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_UpL10nDelegate old) => false;
}

UpL10n lookupUpL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return UpL10nEn();
    case 'zh':
      return UpL10nZh();
  }

  throw FlutterError(
    'UpL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
