import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../l10n/generated/app_localizations.dart';
import '../state/app_state.dart';
import '../widgets/app_menu.dart';
import '../widgets/tessera_logo.dart';

/// The start screen: the logo, faded into the background, and two
/// buttons — or, while a file given on the command line is read, a
/// progress bar in their place.
///
/// Files can also be dropped on it (Windows, Linux, web; macOS once
/// that target exists). Stateful for the [AppLifecycleListener] — the
/// clipboard cannot notify us, so its emptiness is checked when the
/// page appears and whenever the app comes back to the foreground —
/// and for the drag-over highlight.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _state = GetIt.I<AppState>();
  late final AppLifecycleListener _lifecycle;
  var _dragging = false;

  /// Where `desktop_drop` is wired up for this app.
  static bool get dropSupported =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;

  void _dropped(DropDoneDetails details) {
    setState(() => _dragging = false);
    final file = details.files
        .where((f) => f is! DropItemDirectory)
        .firstOrNull;
    if (file != null) _state.openDropped(file);
  }

  @override
  void initState() {
    super.initState();
    _state.refreshClipboard();
    _lifecycle = AppLifecycleListener(onResume: _state.refreshClipboard);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  static String _describe(AppLocalizations l10n, OpenFailure failure) =>
      switch (failure) {
        UnsupportedFile(:final fileName) => l10n.unsupportedFile(fileName),
        OpenError(:final fileName, :final error) => l10n.openFailed(
          fileName,
          error.toString(),
        ),
        NothingToOpen() => l10n.nothingToOpen,
      };

  Future<void> _open(BuildContext context) async {
    final failure = await _state.openFile();
    if (failure == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_describe(AppLocalizations.of(context), failure))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = _state;
    final Widget body = Stack(
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
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: state.clipboardAvailable.value
                        ? () => state.openFromClipboard(l10n.clipboardName)
                        : null,
                    icon: const Icon(Icons.content_paste),
                    label: Text(l10n.openFromClipboard),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: const [AppMenuButton()],
      ),
      body: !dropSupported
          ? body
          : DropTarget(
              onDragEntered: (_) => setState(() => _dragging = true),
              onDragExited: (_) => setState(() => _dragging = false),
              onDragDone: _dropped,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  body,
                  if (_dragging) _DropOverlay(hint: l10n.dropHint),
                ],
              ),
            ),
    );
  }
}

/// The highlight shown while a file is dragged over the window.
class _DropOverlay extends StatelessWidget {
  const _DropOverlay({required this.hint});

  final String hint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.08),
          border: Border.all(color: scheme.primary, width: 3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.file_download_outlined,
                size: 48,
                color: scheme.primary,
              ),
              const SizedBox(height: 8),
              Text(hint, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
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
