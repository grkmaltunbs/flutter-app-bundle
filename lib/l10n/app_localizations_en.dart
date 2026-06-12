// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => '101 Okey Açar Mı';

  @override
  String get commonBack => 'Back';

  @override
  String get commonGoStart => 'Back to start';

  @override
  String get navHome => 'Home';

  @override
  String get navHistory => 'History';

  @override
  String get navSettings => 'Settings';

  @override
  String get splashEyebrow => '101 OKEY · SCANNER';

  @override
  String get splashHeadline => 'Açar mı?';

  @override
  String get splashSubhead => 'Find out at a glance.';

  @override
  String get splashBody =>
      'Snap your rack. We detect every tile and lay out your best play in seconds.';

  @override
  String get splashContinue => 'Get started';

  @override
  String get splashGuest => 'Continue as guest';

  @override
  String get homeEyebrow => 'AÇAR MI?';

  @override
  String get homeGreetingLine1 => 'Hello,';

  @override
  String get homeGreetingLine2 => 'shall we play?';

  @override
  String get homeHelpSemantics => 'How it works';

  @override
  String get homeGameModeLabel => 'GAME MODE';

  @override
  String get gameMode101Title => '101 Okey';

  @override
  String get gameMode101Sub => 'Open with 101';

  @override
  String get gameModeOkeyTitle => 'Okey';

  @override
  String get gameModeOkeySub => 'Classic';

  @override
  String get homeScanEyebrow => 'NEW SCAN';

  @override
  String get homeScanTitle => 'Snap the rack.';

  @override
  String get homeScanBody => 'Detect every tile — we\'ll find your best play.';

  @override
  String get homeScanSemantics => 'Scan a new rack';

  @override
  String get homeLastScanLabel => 'LAST SCAN';

  @override
  String get homeSeeAll => 'See all →';

  @override
  String get homeEmptyTitle => 'No scans yet';

  @override
  String get homeEmptyBody => 'Scan your first rack to see your best opening.';

  @override
  String get tutorialEyebrow => 'HOW IT WORKS';

  @override
  String get tutorialTitle => 'Three steps, the right move.';

  @override
  String get tutorialStep1Title => 'Snap the rack';

  @override
  String get tutorialStep1Body =>
      'Hold your phone above the rack so every tile is visible to the camera.';

  @override
  String get tutorialStep2Title => 'AI does the rest';

  @override
  String get tutorialStep2Body =>
      'Color and number are detected in seconds. Tap any tile to fix mistakes.';

  @override
  String get tutorialStep3Title => 'Best arrangement';

  @override
  String get tutorialStep3Body =>
      'Our solver finds sets and runs, and tells you if you can open with 101.';

  @override
  String get tutorialExampleEyebrow => 'EXAMPLE';

  @override
  String get tutorialExampleIntro => 'This rack opens with 101:';

  @override
  String get tutorialMeldSetLabel => 'SET · 4 COLORS';

  @override
  String get tutorialMeldRunLabel => 'RUN · 5 TILES';

  @override
  String get tutorialTotalLabel => 'TOTAL';

  @override
  String get tutorialTotalValue => '83 + joker = 101 ✓';

  @override
  String get tutorialDone => 'Got it';

  @override
  String get settingsEyebrow => 'SETTINGS';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAppearanceLabel => 'APPEARANCE';

  @override
  String get settingsThemeLabel => 'Theme';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeFelt => 'Felt';

  @override
  String get settingsTileStyleLabel => 'Tile style';

  @override
  String get settingsTileStyleClassic => 'Classic';

  @override
  String get settingsTileStyleFlat => 'Flat';

  @override
  String get settingsTileStyleMinimal => 'Minimal';

  @override
  String get settingsTileStyleBold => 'Bold';

  @override
  String get settingsAccentLabel => 'Accent';

  @override
  String get settingsAccentSage => 'Sage';

  @override
  String get settingsAccentCoral => 'Coral';

  @override
  String get settingsAccentIndigo => 'Indigo';

  @override
  String get settingsAccentAmber => 'Amber';

  @override
  String get settingsLanguageLabel => 'Language';

  @override
  String get settingsLanguageSystem => 'System';

  @override
  String get settingsLanguageTurkish => 'Türkçe';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsGameLabel => 'GAME';

  @override
  String get settingsDefaultModeLabel => 'Default mode';

  @override
  String get settingsAccountLabel => 'ACCOUNT';

  @override
  String get settingsAboutLabel => 'ABOUT';

  @override
  String get settingsVersionLabel => 'Version';

  @override
  String get settingsVersionValue => '1.0.0';

  @override
  String get settingsComingSoon => 'Coming soon';

  @override
  String get historyEyebrow => 'HISTORY';

  @override
  String get historyTitle => 'Your scans';

  @override
  String get historyEmptyTitle => 'No scans yet';

  @override
  String get historyEmptyBody => 'Racks you scan will show up here.';

  @override
  String get historyEmptyCta => 'Scan now';

  @override
  String get placeholderComingSoon => 'Coming soon';

  @override
  String get placeholderBody => 'This screen is on the way.';

  @override
  String get screenCameraTitle => 'Camera';

  @override
  String get screenAnalyzingTitle => 'Analyzing';

  @override
  String get screenReviewTitle => 'Review';

  @override
  String get screenResultTitle => 'Result';

  @override
  String get screenPaywallTitle => 'Premium';

  @override
  String get cameraFrameHint => 'FRAME THE RACK';

  @override
  String get cameraModePhoto => 'Photo';

  @override
  String get cameraModeVideo => 'Video';

  @override
  String get cameraModeGallery => 'Gallery';

  @override
  String get cameraShutterSemantics => 'Capture';

  @override
  String get cameraStopRecordingSemantics => 'Stop capturing';

  @override
  String cameraRecordingProgress(int captured, int total) {
    return 'Frame $captured/$total';
  }

  @override
  String get cameraFlashOnSemantics => 'Turn flash off';

  @override
  String get cameraFlashOffSemantics => 'Turn flash on';

  @override
  String get cameraFlipSemantics => 'Flip camera';

  @override
  String get cameraGallerySemantics => 'Pick from gallery';

  @override
  String get cameraDeniedTitle => 'Camera permission needed';

  @override
  String get cameraDeniedBody =>
      'Allow camera access so we can read your tiles.';

  @override
  String get cameraDeniedRetry => 'Try again';

  @override
  String get cameraPermanentlyDeniedBody =>
      'Camera access is off. You can enable it in Settings.';

  @override
  String get cameraOpenSettings => 'Open Settings';

  @override
  String get cameraGalleryFallback => 'Import from gallery';

  @override
  String get cameraNoCameraTitle => 'No camera found';

  @override
  String get cameraNoCameraBody =>
      'This device has no camera — pick a photo from your gallery.';

  @override
  String get cameraGalleryDeniedTitle => 'Photo access needed';

  @override
  String get cameraGalleryDeniedBody =>
      'Allow photo access to import a rack photo.';

  @override
  String get cameraGalleryPermanentlyDeniedBody =>
      'Photo access is off. You can enable it in Settings.';

  @override
  String get cameraCaptureFailed => 'Capture failed. Try again.';

  @override
  String get analyzingStagePreparing => 'Processing image…';

  @override
  String get analyzingStageLocatingRack => 'Locating the rack…';

  @override
  String get analyzingStageReadingTiles => 'Reading tiles…';

  @override
  String get analyzingStageAggregatingFrames => 'Combining frames…';

  @override
  String get analyzingStageFinalizing => 'Finishing up…';

  @override
  String analyzingTileProgress(int revealed, int total) {
    return '$revealed/$total';
  }

  @override
  String get analyzingCancelSemantics => 'Cancel analysis';

  @override
  String get analyzingNoTilesTitle => 'No tiles found';

  @override
  String get analyzingNoTilesBody =>
      'Make sure the rack fills the frame, both rows are visible, and the light is even — then try again.';

  @override
  String get analyzingRetake => 'Retake';

  @override
  String get analyzingErrorTitle => 'Something went wrong';

  @override
  String get analyzingErrorBody =>
      'The tiles could not be analyzed. Please try again.';

  @override
  String get analyzingRetry => 'Try again';

  @override
  String get reviewStepEyebrow => '2/3 · REVIEW';

  @override
  String get reviewHeadline => 'Did we get it right?';

  @override
  String get reviewSubtitle => 'Tap any wrong tile to fix it.';

  @override
  String get reviewLowConfidenceLegend => 'Low confidence · please review';

  @override
  String get reviewLowOverallBanner =>
      'The image isn\'t very sharp. Retake it, or fix tiles by hand.';

  @override
  String get reviewRetakeCta => 'Retake';

  @override
  String reviewCount(int count, int min, int max) {
    return '$count / $min–$max tiles';
  }

  @override
  String reviewWrongCountFew(int expectedMin) {
    return 'Tiles missing — at least $expectedMin required. Add a tile.';
  }

  @override
  String reviewWrongCountMany(int expectedMax) {
    return 'Too many tiles — at most $expectedMax allowed. Remove one.';
  }

  @override
  String get reviewAddTile => 'Add tile';

  @override
  String reviewEditTileTitle(int index) {
    return 'EDIT TILE · #$index';
  }

  @override
  String get reviewEditColorLabel => 'COLOR';

  @override
  String get reviewEditNumberLabel => 'NUMBER';

  @override
  String get reviewRemoveTile => 'Remove tile';

  @override
  String get reviewIndicatorTitle => 'INDICATOR';

  @override
  String get reviewIndicatorPick => 'Pick indicator';

  @override
  String get reviewIndicatorChange => 'Change';

  @override
  String reviewOkeyLabel(String color, int number) {
    return 'Okey: $color $number';
  }

  @override
  String reviewFalseJokerNote(String color, int number) {
    return 'False jokers stand in for $color $number';
  }

  @override
  String get reviewBlockerCount => 'Fix the tile count first';

  @override
  String get reviewBlockerIncomplete => 'Define the unfinished tiles';

  @override
  String get reviewBlockerIndicator => 'Pick the indicator to calculate';

  @override
  String get reviewCalculateCta => 'Calculate';

  @override
  String reviewTileSemantics(String label, int index, int count) {
    return '$label, tile $index of $count, tap to edit';
  }

  @override
  String get reviewUndefinedTileSemantics => 'Undefined tile, tap to define';

  @override
  String get reviewEditCloseSemantics => 'Close editing';

  @override
  String reviewFalseJokerTileSemantics(String color, int number) {
    return 'False joker, counts as $color $number';
  }

  @override
  String indicatorColorSemantics(String color) {
    return 'Indicator color $color';
  }

  @override
  String indicatorNumberSemantics(int number) {
    return 'Indicator number $number';
  }

  @override
  String get loginEyebrow => 'WELCOME';

  @override
  String get loginTitleSignIn => 'Welcome back.';

  @override
  String get loginTitleSignUp => 'Make an account.';

  @override
  String get loginSubtitle => 'Continue with email, or connect.';

  @override
  String get loginEmailHint => 'Email address';

  @override
  String get loginPasswordHint => 'Password';

  @override
  String get loginForgot => 'Forgot password';

  @override
  String get loginSubmitSignIn => 'Sign in';

  @override
  String get loginSubmitSignUp => 'Create account';

  @override
  String get loginDividerOr => 'OR';

  @override
  String get loginGoogle => 'Continue with Google';

  @override
  String get loginApple => 'Continue with Apple';

  @override
  String get loginGuest => 'Continue as guest';

  @override
  String get loginNoAccount => 'No account yet?';

  @override
  String get loginHaveAccount => 'Already have an account?';

  @override
  String get loginModeToggleToSignUp => 'Sign up';

  @override
  String get loginModeToggleToSignIn => 'Sign in';

  @override
  String get textFieldShowPassword => 'Show password';

  @override
  String get textFieldHidePassword => 'Hide password';

  @override
  String get authErrorEmailEmpty => 'Email address is required.';

  @override
  String get authErrorEmailInvalid => 'Enter a valid email address.';

  @override
  String get authErrorEmailInUse =>
      'This email is already registered. Try signing in.';

  @override
  String get authErrorPasswordEmpty => 'Password is required.';

  @override
  String get authErrorPasswordTooShort =>
      'Password must be at least 6 characters.';

  @override
  String get authErrorInvalidCredentials => 'Incorrect email or password.';

  @override
  String get authErrorNetwork => 'Connection error. Try again.';

  @override
  String get authErrorTooManyRequests =>
      'Too many attempts. Wait a moment and try again.';

  @override
  String get authErrorUnexpected => 'Something went wrong. Try again.';

  @override
  String get authErrorRequiresRecentLogin =>
      'This action needs a recent sign-in. Verify your identity again.';

  @override
  String get authErrorSessionExpired => 'Your session expired. Sign in again.';

  @override
  String get forgotTitle => 'Reset your password';

  @override
  String get forgotBody => 'We will send a reset link to your email address.';

  @override
  String get forgotSubmit => 'Send link';

  @override
  String get forgotSentTitle => 'Link sent';

  @override
  String get forgotSentBody => 'Check your inbox. It may take a few minutes.';

  @override
  String get forgotClose => 'Close';

  @override
  String get settingsAccountGuestLabel => 'You are using the app as a guest';

  @override
  String get settingsAccountSignUpCta => 'Sign up';

  @override
  String get settingsAccountUnverifiedPill => 'EMAIL NOT VERIFIED';

  @override
  String get settingsAccountResendVerification => 'Resend';

  @override
  String get settingsAccountVerificationSent => 'Sent';

  @override
  String get settingsSignOut => 'Sign out';

  @override
  String get settingsDeleteAccount => 'Delete account';

  @override
  String get deleteTitle => 'You are about to delete your account';

  @override
  String get deleteWarning =>
      'This cannot be undone. Your account and data will be permanently deleted.';

  @override
  String get deleteCancel => 'Cancel';

  @override
  String get deleteConfirmCta => 'Delete account';

  @override
  String get deleteReauthTitle => 'Verify your identity to continue';

  @override
  String get deleteReauthPasswordHint => 'Your password';

  @override
  String get deleteReauthSubmit => 'Verify and delete';

  @override
  String get deleteReauthGoogle => 'Verify with Google';

  @override
  String get deleteReauthApple => 'Verify with Apple';

  @override
  String get deleteInProgress => 'Deleting your account…';

  @override
  String get deleteDoneTitle => 'Account deleted';

  @override
  String get deleteDoneBody => 'You can keep using the app as a guest.';

  @override
  String get deleteDoneCta => 'Done';

  @override
  String get sessionExpiredBanner =>
      'Your session expired — please sign in again.';

  @override
  String get sessionExpiredSignIn => 'Sign in';

  @override
  String get sessionExpiredDismiss => 'Dismiss';

  @override
  String get resultStepEyebrow => '3/3 · RESULT';

  @override
  String get resultCloseSemantics => 'Close result';

  @override
  String get resultSolving => 'Calculating…';

  @override
  String get resultErrorTitle => 'Could not calculate';

  @override
  String get resultErrorBody => 'The solver hit an error. Please try again.';

  @override
  String get resultRetry => 'Try again';

  @override
  String get resultAgain => 'Again';

  @override
  String get resultDone => 'Done';

  @override
  String get resultOpensEyebrow => 'YOU CAN OPEN';

  @override
  String get resultClosesEyebrow => 'NOT YET';

  @override
  String get resultOpensVerdict => 'Opens.';

  @override
  String get resultClosesVerdict => 'No open.';

  @override
  String get resultScoreLabel => 'SCORE';

  @override
  String get resultScoreOutOf => '/ 101';

  @override
  String resultPointsShort(int points) {
    return '$points short. Best possible play:';
  }

  @override
  String get resultOpensViaPairs => 'Opens with five pairs.';

  @override
  String get resultOkeyEyebrow => 'BEST HAND';

  @override
  String get resultOkeyWin => 'Winning hand.';

  @override
  String resultOkeyTilesToWinHeadline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tiles to go.',
      one: '1 tile to go.',
    );
    return '$_temp0';
  }

  @override
  String get resultOkeyTilesToWinLabel => 'TILES TO WIN';

  @override
  String get resultOkeyViaSevenPairs => 'Via seven pairs.';

  @override
  String resultTilesNeeded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tiles needed',
      one: '1 tile needed',
    );
    return '$_temp0';
  }

  @override
  String get resultDiscardSuggestion => 'DISCARD';

  @override
  String get resultBestArrangement => 'BEST ARRANGEMENT';

  @override
  String get resultGroups => 'GROUPS';

  @override
  String get resultLayoutRack => 'Rack';

  @override
  String get resultLayoutList => 'List';

  @override
  String get resultMeldRun => 'Run';

  @override
  String get resultMeldSet => 'Set';

  @override
  String get resultPairLabel => 'Pair';

  @override
  String resultLegendTileCount(int count) {
    return '$count tiles';
  }

  @override
  String resultLeftover(int count) {
    return 'Leftover · $count';
  }

  @override
  String get resultWhyThis => 'WHY THIS?';

  @override
  String get resultDetailLockedTitle => 'Detailed reasoning';

  @override
  String get resultDetailLockedBody => 'Unlock the step-by-step explanation.';

  @override
  String get resultDetailUnlockCta => 'Unlock';

  @override
  String resultReasonOkeyDerived(String indicator, String okey) {
    return 'Indicator $indicator → okey is $okey.';
  }

  @override
  String resultReasonWildsCounted(int falseJokers, int okeyCopies) {
    return 'Counted $falseJokers false jokers, $okeyCopies okey tiles.';
  }

  @override
  String resultReasonRackCountNoted(int count, String mode) {
    return '$count tiles on the rack ($mode).';
  }

  @override
  String resultReasonCountsClamped(String kind, int dropped) {
    return 'Dropped $dropped extra copies of $kind.';
  }

  @override
  String resultReasonMeldFormed(String meld, int runningTotal) {
    return 'Formed $meld → running total $runningTotal.';
  }

  @override
  String resultReasonThresholdOpens(int total, int threshold) {
    return 'Total $total ≥ $threshold — opens.';
  }

  @override
  String resultReasonThresholdShort(int total, int threshold) {
    return 'Total $total < $threshold — does not open.';
  }

  @override
  String resultReasonPairsCountedOpens(int pairCount) {
    return 'Found $pairCount pairs — opens with five pairs.';
  }

  @override
  String resultReasonPairsCounted(int pairCount) {
    return 'Found $pairCount pairs.';
  }

  @override
  String resultReasonPathChosen(String path) {
    return 'Opening path: $path.';
  }

  @override
  String get resultPathMelds => 'runs and sets';

  @override
  String get resultPathPairs => 'five pairs';

  @override
  String resultReasonOkeyTemplateChosen(
    String template,
    int matched,
    int wildsUsed,
  ) {
    return '$template: $matched tiles placed, $wildsUsed wilds used.';
  }

  @override
  String get resultTemplateMeldsAndPair => 'Melds + pair';

  @override
  String get resultTemplateSevenPairs => 'Seven pairs';

  @override
  String resultReasonTilesNeeded(String tiles) {
    return 'Tiles needed: $tiles.';
  }

  @override
  String resultReasonDiscardSuggested(String tile) {
    return 'Suggested discard: $tile.';
  }

  @override
  String resultReasonTilesToWin(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tiles to win.',
      one: '1 tile to win.',
    );
    return '$_temp0';
  }

  @override
  String resultMeldRunDescription(String color, int first, int last) {
    return '$color run $first–$last';
  }

  @override
  String resultMeldSetDescription(int number, int count) {
    return 'set of ${number}s ($count colors)';
  }

  @override
  String resultCellSemantics(String tile, String group) {
    return '$tile, $group';
  }

  @override
  String resultGroupSemantics(String label, int index) {
    return '$label, group $index';
  }

  @override
  String resultNeededTileSemantics(String tile) {
    return 'Needed tile: $tile';
  }

  @override
  String resultWildTileSemantics(String tile) {
    return 'Wild, playing as $tile';
  }

  @override
  String resultDiscardTileSemantics(String tile) {
    return 'Suggested discard: $tile';
  }

  @override
  String get resultModeOneZeroOne => '101 Okey';

  @override
  String get resultModeOkey => 'Okey';

  @override
  String tileSemantics(String color, int number) {
    return '$color $number';
  }

  @override
  String get jokerSemantics => 'Joker';

  @override
  String get tileColorRed => 'Red';

  @override
  String get tileColorBlack => 'Black';

  @override
  String get tileColorYellow => 'Yellow';

  @override
  String get tileColorBlue => 'Blue';
}
