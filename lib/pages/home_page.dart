import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../l10n/generated/app_localizations.dart';
import '../state/app_state.dart';
import '../widgets/tessera_logo.dart';

/// The start screen: the logo, faded into the background, and one button.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _open(BuildContext context) async {
    final failure = await GetIt.I<AppState>().openFile();
    if (failure == null || !context.mounted) return;
    final l10n = AppLocalizations.of(context);
    final message = switch (failure) {
      UnsupportedFile(:final fileName) => l10n.unsupportedFile(fileName),
      OpenError(:final fileName, :final error) => l10n.openFailed(
        fileName,
        error.toString(),
      ),
    };
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = GetIt.I<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Center(
            child: FractionallySizedBox(
              widthFactor: 0.6,
              heightFactor: 0.6,
              child: TesseraLogo(opacity: 0.5),
            ),
          ),
          Center(
            child: SignalBuilder(
              builder: (context) => state.opening.value
                  ? const CircularProgressIndicator()
                  : FilledButton.icon(
                      onPressed: () => _open(context),
                      icon: const Icon(Icons.folder_open),
                      label: Text(l10n.openFile),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
