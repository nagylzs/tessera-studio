import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import 'app.dart';
import 'di.dart';
import 'state/app_state.dart';

/// Desktop runners pass the command line through: the single optional
/// argument is a file path or an http(s) URL to open right away (extra
/// arguments are ignored). Web and Android get no arguments here.
void main(List<String> args) {
  registerServices();
  if (args.isNotEmpty) GetIt.I<AppState>().loadFrom(args.first);
  runApp(const TesseraStudioApp());
}
