import 'dart:async';

import 'package:angel3_configuration/angel3_configuration.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:file/local.dart';

Future<void> main() async {
  var app = Angel();
  var fs = const LocalFileSystem();
  await app.configure(configuration(fs));
}
