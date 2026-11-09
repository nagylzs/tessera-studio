import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:tessera_flutter/tessera_flutter.dart';

import '../l10n/generated/app_localizations.dart';
import '../state/settings.dart';
import '../style/style_gallery.dart';

/// "Grid style…": every style of the [StyleGallery] as a small sample
/// pivot in it, in the app's light or dark, and above them the switch that
/// says which depths pick the colours, for whichever style. A tap applies
/// a style and returns to the pivot, as the language and theme dialogs do
/// (the previews have already been compared; owner, 2026-11-09); the switch
/// leaves the page open, as it changes every preview. Back changes nothing.
class StyleGalleryPage extends StatelessWidget {
  const StyleGalleryPage({super.key});

  /// Width of a tile at most; a phone shows one or two per row.
  static const tileWidth = 300.0;

  /// The box each preview is drawn in at its own sizes before the tile
  /// scales it: room for the largest style's.
  static const canvas = Size(500, 320);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = GetIt.I<AppSettings>();
    final gallery = GetIt.I<StyleGallery>();
    final language = Localizations.localeOf(context).languageCode;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.menuGridStyle.replaceAll('…', ''))),
      body: SignalBuilder(
        builder: (context) {
          final chosen = gallery.byId(settings.gridStyle.value).id;
          final coloring = settings.depthColoring.value;
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _DepthSwitch(
                  value: coloring,
                  onChanged: settings.setDepthColoring,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: tileWidth,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    // the preview's proportions, and a line for the name
                    childAspectRatio: 1.3,
                  ),
                  itemCount: gallery.styles.length,
                  itemBuilder: (context, i) {
                    final style = gallery.styles[i];
                    return _StyleTile(
                      name: style.name(language),
                      theme: CubeTheme.fromStyle(
                        style,
                        coloring: coloring,
                        fontFamilies: styleFontFamilies,
                      ),
                      selected: style.id == chosen,
                      onTap: () {
                        settings.setGridStyle(style.id);
                        Navigator.of(context).pop();
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DepthSwitch extends StatelessWidget {
  const _DepthSwitch({required this.value, required this.onChanged});

  final DepthColoring value;
  final ValueChanged<DepthColoring> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.depthColoring, style: text.titleSmall),
          const SizedBox(height: 2),
          Text(l10n.depthColoringHint, style: text.bodySmall),
          const SizedBox(height: 8),
          // sideways rather than cut, in a narrow window at a large text
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<DepthColoring>(
              showSelectedIcon: false,
              segments: [
                for (final coloring in DepthColoring.values)
                  ButtonSegment(
                    value: coloring,
                    label: Text(switch (coloring) {
                      DepthColoring.off => l10n.depthColoringOff,
                      DepthColoring.rows => l10n.depthColoringRows,
                      DepthColoring.columns => l10n.depthColoringColumns,
                      DepthColoring.both => l10n.depthColoringBoth,
                    }),
                  ),
              ],
              selected: {value},
              onSelectionChanged: (s) => onChanged(s.first),
            ),
          ),
        ],
      ),
    );
  }
}

class _StyleTile extends StatelessWidget {
  const _StyleTile({
    required this.name,
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final CubeTheme theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      // one node for the tile: its name, its state and its tap
      onTap: onTap,
      excludeSemantics: true,
      child: Card.outlined(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 3 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  // every style on one canvas, scaled alike: a compact one
                  // shows smaller than a high-contrast one
                  child: IgnorePointer(
                    child: FittedBox(
                      child: SizedBox(
                        width: StyleGalleryPage.canvas.width,
                        height: StyleGalleryPage.canvas.height,
                        child: CubeStylePreview(theme: theme, fit: BoxFit.none),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: Theme.of(context).textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (selected)
                      Icon(Icons.check_circle, color: scheme.primary, size: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
