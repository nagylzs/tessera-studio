import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../l10n/generated/app_localizations.dart';
import '../state/app_state.dart';
import '../widgets/tessera_logo.dart';

/// The start screen: the logo, faded into the background, and one
/// button — or, while a file given on the command line is read, a
/// progress bar in its place.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static String _describe(AppLocalizations l10n, OpenFailure failure) =>
      switch (failure) {
        UnsupportedFile(:final fileName) => l10n.unsupportedFile(fileName),
        OpenError(:final fileName, :final error) => l10n.openFailed(
          fileName,
          error.toString(),
        ),
      };

  Future<void> _open(BuildContext context) async {
    final failure = await GetIt.I<AppState>().openFile();
    if (failure == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_describe(AppLocalizations.of(context), failure))),
    );
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
              builder: (context) {
                final progress = state.loading.value;
                if (progress != null) {
                  return _Loading(
                    label: l10n.loadingFile(progress.name),
                    fraction: progress.fraction,
                  );
                }
                if (state.opening.value) {
                  return const CircularProgressIndicator();
                }
                final failure = state.loadFailure.value;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (failure != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        child: Text(
                          _describe(l10n, failure),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    FilledButton.icon(
                      onPressed: () => _open(context),
                      icon: const Icon(Icons.folder_open),
                      label: Text(l10n.openFile),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// The sample app's progress block: a fixed-width bar and a line of text.
class _Loading extends StatelessWidget {
  const _Loading({required this.label, required this.fraction});

  final String label;
  final double? fraction;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 240, child: LinearProgressIndicator(value: fraction)),
        const SizedBox(height: 8),
        Text(
          fraction == null
              ? label
              : '$label ${NumberFormat.percentPattern(locale).format(fraction)}',
        ),
      ],
    );
  }
}
