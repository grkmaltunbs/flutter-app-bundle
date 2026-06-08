// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => '101 Okey Açar Mı';

  @override
  String get homeGreeting => 'Açar mı? Bir bakışta öğren.';

  @override
  String get galleryThemeLabel => 'Tema';

  @override
  String get galleryThemeLight => 'Açık';

  @override
  String get galleryThemeDark => 'Koyu';

  @override
  String get galleryThemeSystem => 'Sistem';

  @override
  String get galleryThemeFelt => 'Masa';

  @override
  String get galleryTileStyleLabel => 'Taş stili';

  @override
  String get galleryTileStyleClassic => 'Klasik';

  @override
  String get galleryTileStyleFlat => 'Düz';

  @override
  String get galleryTileStyleMinimal => 'Sade';

  @override
  String get galleryTileStyleBold => 'Kalın';

  @override
  String get galleryAccentLabel => 'Vurgu';

  @override
  String get galleryAccentSage => 'Adaçayı';

  @override
  String get galleryAccentCoral => 'Mercan';

  @override
  String get galleryAccentIndigo => 'Çivit';

  @override
  String get galleryAccentAmber => 'Kehribar';

  @override
  String get gallerySectionRack101 => 'Istaka — 101 (21 taş)';

  @override
  String get gallerySectionRackOkey => 'Istaka — Okey (14 taş)';

  @override
  String get gallerySectionMelds => 'Perler';

  @override
  String get gallerySectionTileStyles => 'Taş stilleri';

  @override
  String get gallerySectionComponents => 'Bileşenler';

  @override
  String get galleryMeldRunLabel => 'Seri · mavi';

  @override
  String get galleryMeldSetLabel => 'Küp · 7\'liler';

  @override
  String get galleryPillReady => 'Hazır';

  @override
  String get galleryPillOpens => 'Açar';

  @override
  String get galleryPillCloses => 'Açmaz';

  @override
  String get galleryButtonPrimary => 'Çöz';

  @override
  String get galleryButtonSecondary => 'Tekrar çek';

  @override
  String get galleryButtonAccent => 'Gösterge seç';

  @override
  String tileSemantics(String color, int number) {
    return '$color $number';
  }

  @override
  String get jokerSemantics => 'Okey';

  @override
  String get tileColorRed => 'Kırmızı';

  @override
  String get tileColorBlack => 'Siyah';

  @override
  String get tileColorYellow => 'Sarı';

  @override
  String get tileColorBlue => 'Mavi';
}
