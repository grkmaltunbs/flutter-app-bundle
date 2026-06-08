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

  /// The application title shown on the home screen and stores.
  ///
  /// In en, this message translates to:
  /// **'101 Okey Açar Mı'**
  String get appTitle;

  /// Greeting line shown on the home stub screen.
  ///
  /// In en, this message translates to:
  /// **'Açar mı? Find out at a glance.'**
  String get homeGreeting;

  /// Label for the theme picker row in the design gallery.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get galleryThemeLabel;

  /// No description provided for @galleryThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get galleryThemeLight;

  /// No description provided for @galleryThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get galleryThemeDark;

  /// No description provided for @galleryThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get galleryThemeSystem;

  /// No description provided for @galleryThemeFelt.
  ///
  /// In en, this message translates to:
  /// **'Felt'**
  String get galleryThemeFelt;

  /// Label for the tile-style picker row in the design gallery.
  ///
  /// In en, this message translates to:
  /// **'Tile style'**
  String get galleryTileStyleLabel;

  /// No description provided for @galleryTileStyleClassic.
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get galleryTileStyleClassic;

  /// No description provided for @galleryTileStyleFlat.
  ///
  /// In en, this message translates to:
  /// **'Flat'**
  String get galleryTileStyleFlat;

  /// No description provided for @galleryTileStyleMinimal.
  ///
  /// In en, this message translates to:
  /// **'Minimal'**
  String get galleryTileStyleMinimal;

  /// No description provided for @galleryTileStyleBold.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get galleryTileStyleBold;

  /// Label for the accent picker row in the design gallery.
  ///
  /// In en, this message translates to:
  /// **'Accent'**
  String get galleryAccentLabel;

  /// No description provided for @galleryAccentSage.
  ///
  /// In en, this message translates to:
  /// **'Sage'**
  String get galleryAccentSage;

  /// No description provided for @galleryAccentCoral.
  ///
  /// In en, this message translates to:
  /// **'Coral'**
  String get galleryAccentCoral;

  /// No description provided for @galleryAccentIndigo.
  ///
  /// In en, this message translates to:
  /// **'Indigo'**
  String get galleryAccentIndigo;

  /// No description provided for @galleryAccentAmber.
  ///
  /// In en, this message translates to:
  /// **'Amber'**
  String get galleryAccentAmber;

  /// Section header above the 21-tile rack sample.
  ///
  /// In en, this message translates to:
  /// **'Rack — 101 (21 tiles)'**
  String get gallerySectionRack101;

  /// Section header above the 14-tile rack sample.
  ///
  /// In en, this message translates to:
  /// **'Rack — Okey (14 tiles)'**
  String get gallerySectionRackOkey;

  /// Section header above the meld samples.
  ///
  /// In en, this message translates to:
  /// **'Melds'**
  String get gallerySectionMelds;

  /// Section header above the four tile-style swatches.
  ///
  /// In en, this message translates to:
  /// **'Tile styles'**
  String get gallerySectionTileStyles;

  /// Section header above pills and buttons.
  ///
  /// In en, this message translates to:
  /// **'Components'**
  String get gallerySectionComponents;

  /// No description provided for @galleryMeldRunLabel.
  ///
  /// In en, this message translates to:
  /// **'Run · blue'**
  String get galleryMeldRunLabel;

  /// No description provided for @galleryMeldSetLabel.
  ///
  /// In en, this message translates to:
  /// **'Set · 7s'**
  String get galleryMeldSetLabel;

  /// No description provided for @galleryPillReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get galleryPillReady;

  /// No description provided for @galleryPillOpens.
  ///
  /// In en, this message translates to:
  /// **'Opens'**
  String get galleryPillOpens;

  /// No description provided for @galleryPillCloses.
  ///
  /// In en, this message translates to:
  /// **'Closes'**
  String get galleryPillCloses;

  /// No description provided for @galleryButtonPrimary.
  ///
  /// In en, this message translates to:
  /// **'Solve'**
  String get galleryButtonPrimary;

  /// No description provided for @galleryButtonSecondary.
  ///
  /// In en, this message translates to:
  /// **'Retake'**
  String get galleryButtonSecondary;

  /// No description provided for @galleryButtonAccent.
  ///
  /// In en, this message translates to:
  /// **'Pick indicator'**
  String get galleryButtonAccent;

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
