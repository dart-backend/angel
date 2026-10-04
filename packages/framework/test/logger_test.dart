import 'dart:io';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

void main() {
  group('default logger output', () {
    late List<String> lines;

    setUpAll(() async {
      var result = await Process.run(Platform.resolvedExecutable, [
        'run',
        'test/fixtures/default_logger_main.dart',
      ]);
      expect(result.exitCode, 0, reason: '${result.stderr}');
      lines = (result.stdout as String)
          .split('\n')
          .map((l) => l.trim())
          .toList();
    });

    int count(String line) => lines.where((l) => l == line).length;

    test('prints each record once, however many apps exist', () {
      expect(count('from-app'), 1);
    });

    test('does not print records of other loggers', () {
      expect(count('from-other-library'), 0);
    });

    test('keeps printing after the root listeners are cleared', () {
      expect(count('after-clear'), 1);
    });
  });

  group('application log listeners', () {
    late List<String> received;

    setUp(() {
      received = [];
      Logger.root.onRecord.listen((r) => received.add(r.message));
    });

    tearDown(Logger.root.clearListeners);

    test('survive creating an app with a custom logger', () {
      Angel(logger: Logger('custom'));
      Logger('mine').info('still here');
      expect(received, contains('still here'));
    });

    test('survive replacing an app logger', () {
      var app = Angel()
        ..logger = Logger('custom')
        ..logger = null;
      Logger('mine').info('still here');
      app.logger.info('from the app');
      expect(received, containsAll(['still here', 'from the app']));
    });
  });
}
