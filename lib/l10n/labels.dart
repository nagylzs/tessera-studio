import 'package:tessera_flutter/tessera_flutter.dart';

import 'generated/app_localizations.dart';

/// The app's own labels for tessera enums.
extension AppLabels on AppLocalizations {
  String columnType(ColumnType type) => switch (type) {
    ColumnType.text => columnTypeText,
    ColumnType.integer => columnTypeInteger,
    ColumnType.number => columnTypeNumber,
    ColumnType.boolean => columnTypeBoolean,
    ColumnType.date => columnTypeDate,
    ColumnType.dateTime => columnTypeDateTime,
  };
}
