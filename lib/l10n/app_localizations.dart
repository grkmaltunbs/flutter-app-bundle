import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
    Locale('tr'),
  ];

  /// The application title shown on stores and the MaterialApp.
  ///
  /// In en, this message translates to:
  /// **'101 Okey Açar Mı'**
  String get appTitle;

  /// Accessibility label for back buttons.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// Accessibility label for the header button when there is no back stack and it navigates to the start screen instead.
  ///
  /// In en, this message translates to:
  /// **'Back to start'**
  String get commonGoStart;

  /// Bottom navigation label for the Home tab.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// Bottom navigation label for the History tab.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get navHistory;

  /// Bottom navigation label for the Settings tab.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// Eyebrow above the splash wordmark.
  ///
  /// In en, this message translates to:
  /// **'101 OKEY · SCANNER'**
  String get splashEyebrow;

  /// The serif brand headline on the splash screen (kept in Turkish).
  ///
  /// In en, this message translates to:
  /// **'Açar mı?'**
  String get splashHeadline;

  /// The muted serif subhead under the splash headline.
  ///
  /// In en, this message translates to:
  /// **'Find out at a glance.'**
  String get splashSubhead;

  /// Supporting body copy on the splash screen.
  ///
  /// In en, this message translates to:
  /// **'Snap your rack. We detect every tile and lay out your best play in seconds.'**
  String get splashBody;

  /// Primary CTA on splash that leads to the login screen.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get splashContinue;

  /// Secondary CTA on splash that enters the app as a guest.
  ///
  /// In en, this message translates to:
  /// **'Continue as guest'**
  String get splashGuest;

  /// Eyebrow at the top of the Home screen (kept in Turkish).
  ///
  /// In en, this message translates to:
  /// **'AÇAR MI?'**
  String get homeEyebrow;

  /// First line of the Home greeting.
  ///
  /// In en, this message translates to:
  /// **'Hello,'**
  String get homeGreetingLine1;

  /// Second (muted) line of the Home greeting.
  ///
  /// In en, this message translates to:
  /// **'shall we play?'**
  String get homeGreetingLine2;

  /// Accessibility label for the Home help button (opens tutorial).
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get homeHelpSemantics;

  /// Eyebrow above the game-mode chooser.
  ///
  /// In en, this message translates to:
  /// **'GAME MODE'**
  String get homeGameModeLabel;

  /// Title of the 101 Okey game-mode option.
  ///
  /// In en, this message translates to:
  /// **'101 Okey'**
  String get gameMode101Title;

  /// Subtitle of the 101 Okey game-mode option.
  ///
  /// In en, this message translates to:
  /// **'Open with 101'**
  String get gameMode101Sub;

  /// Title of the plain Okey game-mode option.
  ///
  /// In en, this message translates to:
  /// **'Okey'**
  String get gameModeOkeyTitle;

  /// Subtitle of the plain Okey game-mode option.
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get gameModeOkeySub;

  /// Eyebrow inside the primary scan call-to-action card.
  ///
  /// In en, this message translates to:
  /// **'NEW SCAN'**
  String get homeScanEyebrow;

  /// Serif title inside the primary scan call-to-action card.
  ///
  /// In en, this message translates to:
  /// **'Snap the rack.'**
  String get homeScanTitle;

  /// Supporting copy inside the scan call-to-action card.
  ///
  /// In en, this message translates to:
  /// **'Detect every tile — we\'ll find your best play.'**
  String get homeScanBody;

  /// Accessibility label for the scan call-to-action card.
  ///
  /// In en, this message translates to:
  /// **'Scan a new rack'**
  String get homeScanSemantics;

  /// Eyebrow above the last-scan card on Home.
  ///
  /// In en, this message translates to:
  /// **'LAST SCAN'**
  String get homeLastScanLabel;

  /// Link that opens the History tab from Home.
  ///
  /// In en, this message translates to:
  /// **'See all →'**
  String get homeSeeAll;

  /// Empty-state title shown when there is no scan history.
  ///
  /// In en, this message translates to:
  /// **'No scans yet'**
  String get homeEmptyTitle;

  /// Empty-state body shown when there is no scan history.
  ///
  /// In en, this message translates to:
  /// **'Scan your first rack to see your best opening.'**
  String get homeEmptyBody;

  /// Eyebrow at the top of the tutorial screen.
  ///
  /// In en, this message translates to:
  /// **'HOW IT WORKS'**
  String get tutorialEyebrow;

  /// Serif title of the tutorial screen.
  ///
  /// In en, this message translates to:
  /// **'Three steps, the right move.'**
  String get tutorialTitle;

  /// No description provided for @tutorialStep1Title.
  ///
  /// In en, this message translates to:
  /// **'Snap the rack'**
  String get tutorialStep1Title;

  /// No description provided for @tutorialStep1Body.
  ///
  /// In en, this message translates to:
  /// **'Hold your phone above the rack so every tile is visible to the camera.'**
  String get tutorialStep1Body;

  /// No description provided for @tutorialStep2Title.
  ///
  /// In en, this message translates to:
  /// **'AI does the rest'**
  String get tutorialStep2Title;

  /// No description provided for @tutorialStep2Body.
  ///
  /// In en, this message translates to:
  /// **'Color and number are detected in seconds. Tap any tile to fix mistakes.'**
  String get tutorialStep2Body;

  /// No description provided for @tutorialStep3Title.
  ///
  /// In en, this message translates to:
  /// **'Best arrangement'**
  String get tutorialStep3Title;

  /// No description provided for @tutorialStep3Body.
  ///
  /// In en, this message translates to:
  /// **'Our solver finds sets and runs, and tells you if you can open with 101.'**
  String get tutorialStep3Body;

  /// Eyebrow above the worked example on the tutorial screen.
  ///
  /// In en, this message translates to:
  /// **'EXAMPLE'**
  String get tutorialExampleEyebrow;

  /// No description provided for @tutorialExampleIntro.
  ///
  /// In en, this message translates to:
  /// **'This rack opens with 101:'**
  String get tutorialExampleIntro;

  /// No description provided for @tutorialMeldSetLabel.
  ///
  /// In en, this message translates to:
  /// **'SET · 4 COLORS'**
  String get tutorialMeldSetLabel;

  /// No description provided for @tutorialMeldRunLabel.
  ///
  /// In en, this message translates to:
  /// **'RUN · 5 TILES'**
  String get tutorialMeldRunLabel;

  /// No description provided for @tutorialTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'TOTAL'**
  String get tutorialTotalLabel;

  /// The worked-example total line on the tutorial screen.
  ///
  /// In en, this message translates to:
  /// **'83 + joker = 101 ✓'**
  String get tutorialTotalValue;

  /// Button that dismisses the tutorial.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get tutorialDone;

  /// No description provided for @settingsEyebrow.
  ///
  /// In en, this message translates to:
  /// **'SETTINGS'**
  String get settingsEyebrow;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsAppearanceLabel.
  ///
  /// In en, this message translates to:
  /// **'APPEARANCE'**
  String get settingsAppearanceLabel;

  /// No description provided for @settingsThemeLabel.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsThemeLabel;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeFelt.
  ///
  /// In en, this message translates to:
  /// **'Felt'**
  String get settingsThemeFelt;

  /// No description provided for @settingsTileStyleLabel.
  ///
  /// In en, this message translates to:
  /// **'Tile style'**
  String get settingsTileStyleLabel;

  /// No description provided for @settingsTileStyleClassic.
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get settingsTileStyleClassic;

  /// No description provided for @settingsTileStyleFlat.
  ///
  /// In en, this message translates to:
  /// **'Flat'**
  String get settingsTileStyleFlat;

  /// No description provided for @settingsTileStyleMinimal.
  ///
  /// In en, this message translates to:
  /// **'Minimal'**
  String get settingsTileStyleMinimal;

  /// No description provided for @settingsTileStyleBold.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get settingsTileStyleBold;

  /// No description provided for @settingsAccentLabel.
  ///
  /// In en, this message translates to:
  /// **'Accent'**
  String get settingsAccentLabel;

  /// No description provided for @settingsAccentSage.
  ///
  /// In en, this message translates to:
  /// **'Sage'**
  String get settingsAccentSage;

  /// No description provided for @settingsAccentCoral.
  ///
  /// In en, this message translates to:
  /// **'Coral'**
  String get settingsAccentCoral;

  /// No description provided for @settingsAccentIndigo.
  ///
  /// In en, this message translates to:
  /// **'Indigo'**
  String get settingsAccentIndigo;

  /// No description provided for @settingsAccentAmber.
  ///
  /// In en, this message translates to:
  /// **'Amber'**
  String get settingsAccentAmber;

  /// No description provided for @settingsLanguageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageLabel;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguageTurkish.
  ///
  /// In en, this message translates to:
  /// **'Türkçe'**
  String get settingsLanguageTurkish;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @settingsGameLabel.
  ///
  /// In en, this message translates to:
  /// **'GAME'**
  String get settingsGameLabel;

  /// No description provided for @settingsDefaultModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Default mode'**
  String get settingsDefaultModeLabel;

  /// No description provided for @settingsAccountLabel.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT'**
  String get settingsAccountLabel;

  /// No description provided for @settingsAboutLabel.
  ///
  /// In en, this message translates to:
  /// **'ABOUT'**
  String get settingsAboutLabel;

  /// No description provided for @settingsVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsVersionLabel;

  /// No description provided for @settingsVersionValue.
  ///
  /// In en, this message translates to:
  /// **'1.0.0'**
  String get settingsVersionValue;

  /// Placeholder text for settings rows not yet implemented.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get settingsComingSoon;

  /// No description provided for @historyEyebrow.
  ///
  /// In en, this message translates to:
  /// **'HISTORY'**
  String get historyEyebrow;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your scans'**
  String get historyTitle;

  /// No description provided for @historyEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No scans yet'**
  String get historyEmptyTitle;

  /// No description provided for @historyEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Racks you scan will show up here.'**
  String get historyEmptyBody;

  /// No description provided for @historyEmptyCta.
  ///
  /// In en, this message translates to:
  /// **'Scan now'**
  String get historyEmptyCta;

  /// Headline on placeholder screens for features not yet built.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get placeholderComingSoon;

  /// Body on placeholder screens for features not yet built.
  ///
  /// In en, this message translates to:
  /// **'This screen is on the way.'**
  String get placeholderBody;

  /// No description provided for @screenCameraTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get screenCameraTitle;

  /// No description provided for @screenAnalyzingTitle.
  ///
  /// In en, this message translates to:
  /// **'Analyzing'**
  String get screenAnalyzingTitle;

  /// No description provided for @screenReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get screenReviewTitle;

  /// No description provided for @screenResultTitle.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get screenResultTitle;

  /// No description provided for @screenPaywallTitle.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get screenPaywallTitle;

  /// Eyebrow at the top of the login screen.
  ///
  /// In en, this message translates to:
  /// **'WELCOME'**
  String get loginEyebrow;

  /// Serif title of the login screen in sign-in mode.
  ///
  /// In en, this message translates to:
  /// **'Welcome back.'**
  String get loginTitleSignIn;

  /// Serif title of the login screen in sign-up mode.
  ///
  /// In en, this message translates to:
  /// **'Make an account.'**
  String get loginTitleSignUp;

  /// Muted subtitle under the login title.
  ///
  /// In en, this message translates to:
  /// **'Continue with email, or connect.'**
  String get loginSubtitle;

  /// Hint for the email field on login and password reset.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get loginEmailHint;

  /// Hint for the password field on the login screen.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get loginPasswordHint;

  /// Link that opens the password-reset sheet (sign-in mode).
  ///
  /// In en, this message translates to:
  /// **'Forgot password'**
  String get loginForgot;

  /// Submit button label in sign-in mode.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginSubmitSignIn;

  /// Submit button label in sign-up mode.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get loginSubmitSignUp;

  /// Divider label between the email form and provider buttons.
  ///
  /// In en, this message translates to:
  /// **'OR'**
  String get loginDividerOr;

  /// Google sign-in button label.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get loginGoogle;

  /// Apple sign-in button label (iOS only).
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get loginApple;

  /// Guest escape button on the login screen.
  ///
  /// In en, this message translates to:
  /// **'Continue as guest'**
  String get loginGuest;

  /// Footer text before the sign-up toggle (sign-in mode).
  ///
  /// In en, this message translates to:
  /// **'No account yet?'**
  String get loginNoAccount;

  /// Footer text before the sign-in toggle (sign-up mode).
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get loginHaveAccount;

  /// Footer link that switches the form to sign-up mode.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get loginModeToggleToSignUp;

  /// Footer link that switches the form to sign-in mode.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginModeToggleToSignIn;

  /// Accessibility label for the eye toggle when the password is hidden.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get textFieldShowPassword;

  /// Accessibility label for the eye toggle when the password is visible.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get textFieldHidePassword;

  /// Inline error when the email field is empty on submit.
  ///
  /// In en, this message translates to:
  /// **'Email address is required.'**
  String get authErrorEmailEmpty;

  /// Inline error when the email does not look like an address.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get authErrorEmailInvalid;

  /// Inline error when signing up with a registered email.
  ///
  /// In en, this message translates to:
  /// **'This email is already registered. Try signing in.'**
  String get authErrorEmailInUse;

  /// Inline error when the password field is empty on submit.
  ///
  /// In en, this message translates to:
  /// **'Password is required.'**
  String get authErrorPasswordEmpty;

  /// Inline error when the sign-up password is too short.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters.'**
  String get authErrorPasswordTooShort;

  /// Banner error for wrong credentials (never reveals which).
  ///
  /// In en, this message translates to:
  /// **'Incorrect email or password.'**
  String get authErrorInvalidCredentials;

  /// Banner error for connectivity failures during auth.
  ///
  /// In en, this message translates to:
  /// **'Connection error. Try again.'**
  String get authErrorNetwork;

  /// Banner error when the backend throttles sign-in attempts.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a moment and try again.'**
  String get authErrorTooManyRequests;

  /// Banner error for any unclassified auth failure.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get authErrorUnexpected;

  /// Banner error when a sensitive action (e.g. account deletion) requires a recent re-authentication.
  ///
  /// In en, this message translates to:
  /// **'This action needs a recent sign-in. Verify your identity again.'**
  String get authErrorRequiresRecentLogin;

  /// Banner error when the stored session is no longer valid.
  ///
  /// In en, this message translates to:
  /// **'Your session expired. Sign in again.'**
  String get authErrorSessionExpired;

  /// Title of the password-reset sheet.
  ///
  /// In en, this message translates to:
  /// **'Reset your password'**
  String get forgotTitle;

  /// Body of the password-reset sheet.
  ///
  /// In en, this message translates to:
  /// **'We will send a reset link to your email address.'**
  String get forgotBody;

  /// Submit button of the password-reset sheet.
  ///
  /// In en, this message translates to:
  /// **'Send link'**
  String get forgotSubmit;

  /// Success title after the reset email is sent.
  ///
  /// In en, this message translates to:
  /// **'Link sent'**
  String get forgotSentTitle;

  /// Success body after the reset email is sent.
  ///
  /// In en, this message translates to:
  /// **'Check your inbox. It may take a few minutes.'**
  String get forgotSentBody;

  /// Button that closes the password-reset sheet.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get forgotClose;

  /// Account section label when signed out.
  ///
  /// In en, this message translates to:
  /// **'You are using the app as a guest'**
  String get settingsAccountGuestLabel;

  /// Account section CTA that opens the login screen.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get settingsAccountSignUpCta;

  /// Pill shown when the account email is not verified.
  ///
  /// In en, this message translates to:
  /// **'EMAIL NOT VERIFIED'**
  String get settingsAccountUnverifiedPill;

  /// Link that re-sends the verification email.
  ///
  /// In en, this message translates to:
  /// **'Resend'**
  String get settingsAccountResendVerification;

  /// Receipt label after the verification email was re-sent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get settingsAccountVerificationSent;

  /// Sign-out button in the account section.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get settingsSignOut;

  /// Destructive entry that opens the account-deletion sheet.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get settingsDeleteAccount;

  /// Title of the deletion confirm step.
  ///
  /// In en, this message translates to:
  /// **'You are about to delete your account'**
  String get deleteTitle;

  /// Irreversibility warning on the deletion confirm step.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone. Your account and data will be permanently deleted.'**
  String get deleteWarning;

  /// Button that abandons the deletion flow.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get deleteCancel;

  /// Destructive button that confirms the deletion intent.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteConfirmCta;

  /// Title of the re-authentication step before deletion.
  ///
  /// In en, this message translates to:
  /// **'Verify your identity to continue'**
  String get deleteReauthTitle;

  /// Hint for the password field in the re-auth step.
  ///
  /// In en, this message translates to:
  /// **'Your password'**
  String get deleteReauthPasswordHint;

  /// Destructive button that re-authenticates and deletes.
  ///
  /// In en, this message translates to:
  /// **'Verify and delete'**
  String get deleteReauthSubmit;

  /// Re-auth button for Google-linked accounts.
  ///
  /// In en, this message translates to:
  /// **'Verify with Google'**
  String get deleteReauthGoogle;

  /// Re-auth button for Apple-linked accounts.
  ///
  /// In en, this message translates to:
  /// **'Verify with Apple'**
  String get deleteReauthApple;

  /// Progress label while the account is being deleted.
  ///
  /// In en, this message translates to:
  /// **'Deleting your account…'**
  String get deleteInProgress;

  /// Title after the account was deleted.
  ///
  /// In en, this message translates to:
  /// **'Account deleted'**
  String get deleteDoneTitle;

  /// Body after the account was deleted.
  ///
  /// In en, this message translates to:
  /// **'You can keep using the app as a guest.'**
  String get deleteDoneBody;

  /// Button that closes the deletion sheet.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get deleteDoneCta;

  /// Banner text when the persisted session failed to restore.
  ///
  /// In en, this message translates to:
  /// **'Your session expired — please sign in again.'**
  String get sessionExpiredBanner;

  /// Banner action that opens the login screen.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get sessionExpiredSignIn;

  /// Accessibility label for the banner dismiss button.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get sessionExpiredDismiss;

  /// Accessibility label for a numbered tile.
  ///
  /// In en, this message translates to:
  /// **'{color} {number}'**
  String tileSemantics(String color, int number);

  /// Accessibility label for the joker (okey) tile.
  ///
  /// In en, this message translates to:
  /// **'Joker'**
  String get jokerSemantics;

  /// No description provided for @tileColorRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get tileColorRed;

  /// No description provided for @tileColorBlack.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get tileColorBlack;

  /// No description provided for @tileColorYellow.
  ///
  /// In en, this message translates to:
  /// **'Yellow'**
  String get tileColorYellow;

  /// No description provided for @tileColorBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get tileColorBlue;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
