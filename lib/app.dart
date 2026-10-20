import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:tessera_flutter/tessera_flutter.dart';

import 'l10n/generated/app_localizations.dart';
import 'pages/failure_page.dart';
import 'pages/home_page.dart';
import 'pages/schema_page.dart';
import 'pages/workbench_page.dart';
import 'state/app_state.dart';
import 'state/settings.dart';

/// The tessera green, also the seed of both colour schemes.
const tesseraGreen = Color(0xFF00856E);

class TesseraStudioApp extends StatefulWidget {
  const TesseraStudioApp({super.key});

  @override
  State<TesseraStudioApp> createState() => _TesseraStudioAppState();
}

class _TesseraStudioAppState extends State<TesseraStudioApp> {
  final _navigator = GlobalKey<NavigatorState>();
  late final EffectCleanup _closeRoutes;

  @override
  void initState() {
    super.initState();
    final state = GetIt.I<AppState>();
    // The root below swaps the page when the document, the failure or the
    // page changes, but what the old page opened on top of it — a sheet,
    // a dialog — would stay, still showing (and acting on) the old file:
    // a file opened from outside arrives whatever is open. Closed after
    // the signal update, outside its notification.
    _closeRoutes = effect(() {
      state.document.value;
      state.failure.value;
      state.page.value;
      scheduleMicrotask(
        () => _navigator.currentState?.popUntil((route) => route.isFirst),
      );
    });
  }

  @override
  void dispose() {
    _closeRoutes();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = GetIt.I<AppState>();
    final settings = GetIt.I<AppSettings>();
    return SignalBuilder(
      builder: (context) => MaterialApp(
        navigatorKey: _navigator,
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
            if (state.failure.value case final failure?) {
              return FailurePage(failure: failure);
            }
            final document = state.document.value;
            if (document == null) return const HomePage();
            return switch (state.page.value) {
              AppPage.home => const HomePage(),
              AppPage.schema => SchemaPage(document: document),
              AppPage.workbench => WorkbenchPage(
                key: ObjectKey(document),
                document: document,
              ),
            };
          },
        ),
      ),
    );
  }
}
