import 'package:flutter/material.dart';

import '../files/file_failure.dart';
import '../l10n/generated/app_localizations.dart';
import 'editors_panel.dart';

/// Why a file could not be opened, in words, with the technical message
/// folded away under "Details" and the ways on as [actions].
class FailureView extends StatelessWidget {
  const FailureView({
    super.key,
    required this.failure,
    this.actions = const [],
  });

  final FileFailure failure;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final format = failure.format;
    final what = format == null
        ? null
        : ImportSummary.formatLabel(l10n, format);
    final message = switch (failure.kind) {
      FailureKind.notUtf8 => l10n.failureNotUtf8,
      FailureKind.damaged when what != null => l10n.failureDamaged(what),
      FailureKind.syntax when what != null => l10n.failureSyntax(what),
      FailureKind.empty => l10n.failureEmpty,
      FailureKind.noRows => l10n.failureNoRows,
      _ => l10n.failureOther,
    };
    final empty =
        failure.kind == FailureKind.empty || failure.kind == FailureKind.noRows;
    final rows = failure.rowsRead;
    final detail = failure.detail;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                empty ? Icons.inbox_outlined : Icons.error_outline,
                size: 48,
                color: empty
                    ? theme.colorScheme.outline
                    : theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.failureTitle(failure.fileName),
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(message),
              if (rows != null) ...[
                const SizedBox(height: 8),
                Text(l10n.failureRowsRead(rows)),
              ],
              if (detail != null) ...[
                const SizedBox(height: 8),
                ExpansionTile(
                  title: Text(l10n.failureDetails),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  expandedAlignment: Alignment.centerLeft,
                  children: [
                    SelectableText(
                      detail,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          ),
        ),
      ),
    );
  }
}
