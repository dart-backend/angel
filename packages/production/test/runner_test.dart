import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_production/angel3_production.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

/// The lines [body] prints, and its result.
Future<(List<String>, T)> capture<T>(Future<T> Function() body) async {
  var lines = <String>[];
  var result = await runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) => lines.add(line),
    ),
  );
  return (lines, result);
}

/// [lines] without their ANSI colours.
List<String> plain(List<String> lines) => [
  for (var line in lines) line.replaceAll(RegExp('\x1B\\[[0-9;]*m'), ''),
];

// The apps of the tests, top-level, so that isolates can run them.

Future<void> failingApp(Angel app) async {
  app.logger.warning('configuring');
  throw StateError('no database');
}

Future<void> closingApp(Angel app) async {
  app.shutdownHooks.add((_) => print('closed the database'));
  app.get('/', (req, res) => 'ok');
}

Future<void> crashingApp(Angel app) async {
  Timer(const Duration(milliseconds: 200), () => Isolate.current.kill());
}

void main() {
  tearDown(() => exitCode = 0);

  test('a failure to start ends the run, with its error', () async {
    var (lines, _) = await capture(
      () => Runner('app', failingApp).run(['-j', '1', '-p', '0']),
    );
    expect(exitCode, isNot(0));
    // Logged once, with its own level, before configureServer failed.
    var warning = plain(lines).where((l) => l.contains('configuring')).toList();
    expect(warning, hasLength(1));
    expect(warning.single, contains('WARNING [app]: configuring'));
    expect(warning.single, isNot(contains('INFO')));
  });

  test('stop closes the instances, running their shutdown hooks', () async {
    var runner = Runner('app', closingApp);
    var (lines, _) = await capture(() async {
      var running = runner.run(['-j', '2', '-p', '0']);
      await Future.delayed(const Duration(seconds: 3));
      runner.stop();
      await running.timeout(const Duration(seconds: 15));
    });
    var text = plain(lines);
    expect(text.where((l) => l.contains('listening at')), hasLength(2));
    expect(text.where((l) => l.contains('closed the database')), hasLength(2));
    expect(exitCode, 0);
  });

  test('a crashing instance is respawned after a growing delay', () async {
    var runner = Runner('app', crashingApp);
    var (lines, _) = await capture(() async {
      var running = runner.run(['-j', '1', '-p', '0']);
      await Future.delayed(const Duration(milliseconds: 4500));
      runner.stop();
      await running.timeout(const Duration(seconds: 15));
    });
    var respawns = plain(lines).where((l) => l.contains('Respawning')).toList();
    expect(respawns.length, greaterThanOrEqualTo(2));
    expect(respawns[0], contains('in 1s'));
    expect(respawns[1], contains('in 2s'));
  });

  group('arguments', () {
    test('a port that is not a number is a usage error', () async {
      await capture(() => Runner('app', closingApp).run(['-p', 'x']));
      expect(exitCode, 64);
    });

    test('a concurrency of 0 is a usage error', () async {
      await capture(() => Runner('app', closingApp).run(['-j', '0']));
      expect(exitCode, 64);
    });

    test('--help is shown before other checks', () async {
      var (lines, _) = await capture(
        () => Runner('app', closingApp).run(['--help', '--ssl']),
      );
      expect(exitCode, 0);
      expect(lines, isNotEmpty);
    });
  });

  test('passwords may be given by environment variables', () {
    expect(RunnerOptions.keyPasswordVariable, 'ANGEL_KEY_PASSWORD');
    expect(
      RunnerOptions.certificatePasswordVariable,
      'ANGEL_CERTIFICATE_PASSWORD',
    );
    var options = RunnerOptions.fromArgResults(
      RunnerOptions.argParser.parse(['--key-password', 'given']),
    );
    expect(options.keyPassword, 'given');
  });

  test('handleLogRecord prints a record once', () async {
    var (lines, _) = await capture(() async {
      Runner.handleLogRecord(
        LogRecord(Level.WARNING, 'hello', 'test'),
        RunnerOptions(),
      );
    });
    expect(plain(lines).single, endsWith('WARNING [test]: hello'));
  });
}
