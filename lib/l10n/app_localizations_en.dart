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
  String get homeGreeting => 'Açar mı? Find out at a glance.';

  @override
  String get galleryThemeLabel => 'Theme';

  @override
  String get galleryThemeLight => 'Light';

  @override
  String get galleryThemeDark => 'Dark';

  @override
  String get galleryThemeSystem => 'System';

  @override
  String get galleryThemeFelt => 'Felt';

  @override
  String get galleryTileStyleLabel => 'Tile style';

  @override
  String get galleryTileStyleClassic => 'Classic';

  @override
  String get galleryTileStyleFlat => 'Flat';

  @override
  String get galleryTileStyleMinimal => 'Minimal';

  @override
  String get galleryTileStyleBold => 'Bold';

  @override
  String get galleryAccentLabel => 'Accent';

  @override
  String get galleryAccentSage => 'Sage';

  @override
  String get galleryAccentCoral => 'Coral';

  @override
  String get galleryAccentIndigo => 'Indigo';

  @override
  String get galleryAccentAmber => 'Amber';

  @override
  String get gallerySectionRack101 => 'Rack — 101 (21 tiles)';

  @override
  String get gallerySectionRackOkey => 'Rack — Okey (14 tiles)';

  @override
  String get gallerySectionMelds => 'Melds';

  @override
  String get gallerySectionTileStyles => 'Tile styles';

  @override
  String get gallerySectionComponents => 'Components';

  @override
  String get galleryMeldRunLabel => 'Run · blue';

  @override
  String get galleryMeldSetLabel => 'Set · 7s';

  @override
  String get galleryPillReady => 'Ready';

  @override
  String get galleryPillOpens => 'Opens';

  @override
  String get galleryPillCloses => 'Closes';

  @override
  String get galleryButtonPrimary => 'Solve';

  @override
  String get galleryButtonSecondary => 'Retake';

  @override
  String get galleryButtonAccent => 'Pick indicator';

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
