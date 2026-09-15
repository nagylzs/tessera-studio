import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:tessera_flutter/tessera_flutter.dart';

import 'l10n/generated/app_localizations.dart';
import 'pages/home_page.dart';
import 'pages/schema_page.dart';
import 'pages/workbench_page.dart';
import 'state/app_state.dart';
import 'state/settings.dart';

/// The tessera green, also the seed of both colour schemes.
const tesseraGreen = Color(0xFF00856E);

class TesseraStudioApp extends StatelessWidget {
  const TesseraStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = GetIt.I<AppState>();
    final settings = GetIt.I<AppSettings>();
    return SignalBuilder(
      builder: (context) => MaterialApp(
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        theme: ThemeData(colorSchemeSeed: tesseraGreen),
        darkTheme: ThemeData(
          colorSchemeSeed: tesseraGreen,
          brightness: Brightness.dark,
        ),
        themeMode: settings.themeMode.value,
        locale: settings.locale.value,
        localizationsDelegates: const [
          ...AppLocalizations.localizationsDelegates,
          TesseraLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: SignalBuilder(
          builder: (context) {
            final document = state.document.value;
            if (document == null) return const HomePage();
            return switch (state.page.value) {
              AppPage.home => const HomePage(),
              AppPage.schema => SchemaPage(document: document),
              AppPage.workbench => WorkbenchPage(document: document),
            };
          },
        ),
      ),
    );
  }
}
