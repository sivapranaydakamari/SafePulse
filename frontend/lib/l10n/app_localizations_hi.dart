// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appName => 'SafePulse';

  @override
  String get sosButtonLabel => 'SOS';

  @override
  String get overspeedWarning => 'आप गति सीमा से अधिक हैं';

  @override
  String get noContactsWarning => 'कोई आपातकालीन संपर्क नहीं मिला';

  @override
  String get safeRouteLabel => 'सबसे सुरक्षित मार्ग';
}
