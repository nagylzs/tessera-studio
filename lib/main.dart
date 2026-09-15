import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import 'app.dart';
import 'di.dart';
import 'files/open_requests.dart';
import 'state/app_state.dart';

/// Desktop runners pass the command line through: the single optional
/// argument is a file path or an http(s) URL to open right away (extra
/// arguments are ignored). Android instead delivers "Open with…" and
/// share-sheet files through [OpenRequests]; the web gets neither yet.
void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();
  registerServices();
  final state = GetIt.I<AppState>();
  if (args.isNotEmpty) state.loadFrom(args.first);
  GetIt.I<OpenRequests>().requests.listen(state.handleOpenRequest);
  runApp(const TesseraStudioApp());
}
