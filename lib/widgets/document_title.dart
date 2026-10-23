import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../files/opened_document.dart';
import '../l10n/generated/app_localizations.dart';
import '../state/app_state.dart';

/// An app bar title about [document]: [title], with [subtitle] in small
/// type below it. A workbook with several sheets adds the sheet shown to
/// the second line, with a ▾, and the whole title opens the list of its
/// sheets ([AppState.openSheet]).
class DocumentTitle extends StatelessWidget {
  const DocumentTitle({
    super.key,
    required this.document,
    required this.title,
    this.subtitle,
  });

  final OpenedDocument document;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;
    final sheet = document.sheet;
    final subtitle = this.subtitle;
    if (document.sheets.length < 2 || sheet == null) {
      if (subtitle == null) return Text(title);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title),
          Text(subtitle, style: small),
        ],
      );
    }
    final state = GetIt.I<AppState>();
    return SignalBuilder(
      builder: (context) => PopupMenuButton<String>(
        tooltip: AppLocalizations.of(context).chooseSheet,
        enabled: !state.busy.value,
        onSelected: state.openSheet,
        // wider than a menu's 280: sheet names have no spaces to wrap at
        constraints: const BoxConstraints(minWidth: 112, maxWidth: 420),
        itemBuilder: (context) => [
          for (final s in document.sheets)
            CheckedPopupMenuItem(value: s, checked: s == sheet, child: Text(s)),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title),
            // with a subtitle, the sheet's name whole (up to most of the
            // line) and the subtitle in what is left
            LayoutBuilder(
              builder: (context, constraints) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (subtitle != null) ...[
                    Flexible(child: Text(subtitle, style: small)),
                    Text(' · ', style: small),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth * 0.6,
                      ),
                      child: Text(sheet, style: small),
                    ),
                  ] else
                    Flexible(child: Text(sheet, style: small)),
                  Icon(Icons.arrow_drop_down, size: 18, color: small?.color),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
