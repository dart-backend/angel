/// Run by `logger_test.dart` as a subprocess: the default logger prints via
/// the root zone, so its output can only be observed on stdout.
library;

import 'dart:io';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:logging/logging.dart';

Future<void> main() async {
  var first = Angel();
  Angel();
  Angel();

  first.logger.info('from-app');
  Logger('other-library').info('from-other-library');

  // Clearing the root logger's listeners must not stop default printing
  // for apps created afterwards.
  Logger.root.clearListeners();
  await Future<void>.delayed(Duration.zero);
  Angel().logger.info('after-clear');

  await Future<void>.delayed(Duration.zero);
  exit(0);
}
