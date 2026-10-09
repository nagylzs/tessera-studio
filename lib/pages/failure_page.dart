import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../files/file_failure.dart';
import '../l10n/generated/app_localizations.dart';
import '../state/app_state.dart';
import '../widgets/app_menu.dart';
import '../widgets/failure_view.dart';
import '../widgets/open_file.dart';

/// A file that was read but could not be opened ([AppState.failure]),
/// over whatever was shown before; close or back returns there.
class FailurePage extends StatelessWidget {
  const FailurePage({super.key, required this.failure});

  final FileFailure failure;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = GetIt.I<AppState>();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) state.dismissFailure();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: state.dismissFailure,
          ),
          title: Text(failure.fileName),
          actions: const [AppMenuButton()],
        ),
        body: FailureView(
          failure: failure,
          actions: [
            FilledButton.icon(
              icon: const Icon(Icons.folder_open),
              label: Text(l10n.openAnotherFile),
              onPressed: () => pickAndOpen(context),
            ),
            TextButton(
              onPressed: state.dismissFailure,
              child: Text(MaterialLocalizations.of(context).closeButtonLabel),
            ),
          ],
        ),
      ),
    );
  }
}
