import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../files/file_failure.dart';
import '../l10n/generated/app_localizations.dart';
import '../state/app_state.dart';

/// Why opening did not even get to read a file, as one line.
String describeOpenFailure(AppLocalizations l10n, OpenFailure failure) =>
    switch (failure) {
      UnsupportedFile(:final fileName) => l10n.unsupportedFile(fileName),
      OpenError(:final fileName, :final error) => l10n.openFailed(
        fileName,
        FileFailure.describe(error),
      ),
      NothingToOpen() => l10n.nothingToOpen,
    };

/// The picker, then the open flow; a failure before the file is read
/// goes to a snack bar (one that was read gets the failure page).
Future<void> pickAndOpen(BuildContext context) async {
  final failure = await GetIt.I<AppState>().openFile();
  if (failure == null || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(describeOpenFailure(AppLocalizations.of(context), failure)),
    ),
  );
}
