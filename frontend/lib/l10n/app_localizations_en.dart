// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'SafePulse';

  @override
  String get sosButtonLabel => 'SOS';

  @override
  String get overspeedWarning => 'You are over the speed limit';

  @override
  String get noContactsWarning => 'No emergency contacts found';

  @override
  String get safeRouteLabel => 'Safest route';
}
