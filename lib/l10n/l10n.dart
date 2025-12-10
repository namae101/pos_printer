import 'package:flutter/widgets.dart';
import 'package:pos_printer/l10n/gen/app_localizations.dart';

export 'package:pos_printer/l10n/gen/app_localizations.dart';

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
