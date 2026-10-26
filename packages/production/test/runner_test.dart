import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_production/angel3_production.dart';
import 'package:belatuk_pub_sub/belatuk_pub_sub.dart';
import 'package:belatuk_pub_sub/isolate.dart';
import 'package:http2/http2.dart' as h2;
import 'package:logging/logging.dart';
import 'package:test/test.dart';

/// The lines [body] prints (into [lines], if given), and its result.
Future<(List<String>, T)> capture<T>(
  Future<T> Function() body, [
  List<String>? lines,
]) async {
  lines ??= <String>[];
  var result = await runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) => lines!.add(line),
    ),
  );
  return (lines, result);
}

/// Waits until a line of [lines] that contains [text] has been printed
/// [count] times.
Future<void> printed(
  List<String> lines,
  String text, {
  int count = 1,
  Duration timeout = const Duration(seconds: 20),
}) async {
  var deadline = DateTime.now().add(timeout);
  while (lines.where((l) => l.contains(text)).length < count) {
    if (DateTime.now().isAfter(deadline)) {
      fail('"$text" was not printed $count times in:\n${lines.join('\n')}');
    }
    await Future.delayed(const Duration(milliseconds: 50));
  }
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

const slowPort = 3921;

Future<void> slowApp(Angel app) async {
  var open = true;
  app.shutdownHooks.add((_) => open = false);
  app.get('/slow', (req, res) async {
    print('handling');
    await Future.delayed(const Duration(milliseconds: 500));
    return open ? 'open' : 'closed';
  });
}

/// Fails to start as instance #0, and starts as any other.
Future<void> firstFailsApp(Angel app) async {
  if (app.container.make<InstanceInfo>().id == 0) {
    throw StateError('instance #0 fails');
  }
  app.shutdownHooks.add((_) => print('closed instance'));
}

/// The headers the header tests configure: as defaults, less those removed.
const testResponseHeaders = <String, Object>{
  'vary': ['accept', 'origin'],
  'cache-control': 'no-store',
  // With attributes, which an HTTP/2 response's copy of it keeps.
  'set-cookie': ['a=1', 'b=2', 'c=3; Path=/x; HttpOnly'],
  'x-list': ['a', 'b'],
  // Names that differ in case, merged as HttpHeaders.add merges them.
  'X-Case': 'a',
  'x-case': 'b',
  'x-gone': 'a',
};
const testRemovedHeaders = <String, Object?>{
  // Matched ignoring case, as dart:io stores SAMEORIGIN.
  'x-frame-options': 'sameorigin',
  'x-list': ['b'],
  // Whatever their values: a default of dart:io, and a configured one.
  'x-xss-protection': null,
  'x-gone': null,
};

/// Responds on `/` without headers of its own, and on `/own` with some.
Future<void> headersApp(Angel app) async {
  app.get('/', (req, res) => 'ok');
  app.get('/cookie', (req, res) {
    res.cookies.add(Cookie('a', '5'));
    return 'ok';
  });
  app.get('/own', (req, res) {
    res.headers
      ..['cache-control'] = 'public'
      ..['x-frame-options'] = 'DENY';
    return 'ok';
  });
}

/// The name of the cookie of a `set-cookie` value.
String cookieName(String setCookie) => setCookie.split('=').first;

/// The headers of an HTTP/2 GET of [path] at [url], with each value of a
/// header that is sent several times.
Future<Map<String, List<String>>> http2Headers(Uri url, String path) async {
  var socket = await SecureSocket.connect(
    url.host,
    url.port,
    supportedProtocols: ['h2'],
    onBadCertificate: (_) => true,
  );
  var transport = h2.ClientTransportConnection.viaSocket(socket);
  var headers = <String, List<String>>{};
  var stream = transport.makeRequest([
    h2.Header.ascii(':method', 'GET'),
    h2.Header.ascii(':path', path),
    h2.Header.ascii(':scheme', 'https'),
    h2.Header.ascii(':authority', url.authority),
  ], endStream: true);
  await for (var message in stream.incomingMessages) {
    if (message is h2.HeadersStreamMessage) {
      for (var header in message.headers) {
        headers
            .putIfAbsent(String.fromCharCodes(header.name), () => [])
            .add(String.fromCharCodes(header.value));
      }
    }
  }
  await transport.finish();
  return headers;
}

/// Logs, a second after it starts, the time it logs at.
Future<void> laterLoggingApp(Angel app) async {
  Timer(const Duration(seconds: 1), () {
    app.logger.info('logged at ${DateTime.now().toIso8601String()}');
  });
}

/// Marks that [flakyApp] has started once, as isolates share no memory.
final flakyMarker = File(
  '${Directory.systemTemp.path}/angel3_production_flaky_$pid',
);

/// Starts once, then crashes, and fails to start again.
Future<void> flakyApp(Angel app) async {
  if (flakyMarker.existsSync()) throw StateError('no database');
  flakyMarker.createSync();
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
    var lines = <String>[];
    await capture(() async {
      var running = runner.run(['-j', '2', '-p', '0']);
      await printed(lines, 'listening at', count: 2);
      runner.stop();
      await running.timeout(const Duration(seconds: 15));
    }, lines);
    var text = plain(lines);
    expect(text.where((l) => l.contains('listening at')), hasLength(2));
    expect(text.where((l) => l.contains('closed the database')), hasLength(2));
    expect(exitCode, 0);
  });

  test('a crashing instance is respawned after a growing delay', () async {
    var runner = Runner('app', crashingApp);
    var lines = <String>[];
    await capture(() async {
      var running = runner.run(['-j', '1', '-p', '0']);
      await printed(lines, 'Respawning', count: 2);
      runner.stop();
      await running.timeout(const Duration(seconds: 15));
    }, lines);
    var respawns = plain(lines).where((l) => l.contains('Respawning')).toList();
    expect(respawns[0], contains('in 1s'));
    expect(respawns[1], contains('in 2s'));
    expect(exitCode, 0);
  });

  test('a failure to start again after a crash is respawned', () async {
    addTearDown(() {
      if (flakyMarker.existsSync()) flakyMarker.deleteSync();
    });
    var runner = Runner('app', flakyApp);
    var lines = <String>[];
    await capture(() async {
      var running = runner.run(['-j', '1', '-p', '0']);
      await printed(lines, 'failed to start again', count: 2);
      runner.stop();
      await running.timeout(const Duration(seconds: 15));
    }, lines);
    expect(lines.where((l) => l.contains('no database')), isNotEmpty);
    expect(exitCode, 0);
  });

  test('stop lets requests in progress finish, before the hooks', () async {
    var runner = Runner('app', slowApp);
    var lines = <String>[];
    var client = HttpClient();
    addTearDown(() => client.close(force: true));
    late String body;
    await capture(() async {
      var running = runner.run(['-j', '1', '-p', '$slowPort']);
      await printed(lines, 'listening at');
      var response = client
          .get('127.0.0.1', slowPort, '/slow')
          .then((rq) => rq.close())
          .then((rs) => rs.transform(const SystemEncoding().decoder).join());
      await printed(lines, 'handling');
      runner.stop();
      body = await response.timeout(const Duration(seconds: 10));
      await running.timeout(const Duration(seconds: 15));
    }, lines);
    expect(body, '"open"');
  });

  test('with --http2, stop lets HTTP/1 requests finish', () async {
    var runner = Runner('app', slowApp);
    var lines = <String>[];
    var client = HttpClient()..badCertificateCallback = (_, _, _) => true;
    addTearDown(() => client.close(force: true));
    late String body;
    await capture(() async {
      var running = runner.run([
        '-j', '1', '-p', '0', '--http2', //
        '--certificate-file', 'test/dev.pem',
        '--key-file', 'test/dev.key', '--key-password', 'dartdart',
      ]);
      await printed(lines, 'listening at');
      var url = RegExp(r'listening at (\S+)')
          .firstMatch(plain(lines).join('\n'))![1]!;
      // Without ALPN, so it is served by the HTTP/1 fallback.
      var response = client
          .getUrl(Uri.parse(url).replace(path: '/slow'))
          .then((rq) => rq.close())
          .then((rs) => rs.transform(const SystemEncoding().decoder).join());
      await printed(lines, 'handling');
      runner.stop();
      body = await response.timeout(const Duration(seconds: 10));
      await running.timeout(const Duration(seconds: 15));
    }, lines);
    expect(body, '"open"');
  });

  test('with --http2, the response headers apply as with HTTP/1', () async {
    var runner = Runner(
      'app',
      headersApp,
      removeResponseHeaders: testRemovedHeaders,
      responseHeaders: testResponseHeaders,
    );
    var lines = <String>[];
    var client = HttpClient()..badCertificateCallback = (_, _, _) => true;
    addTearDown(() => client.close(force: true));
    var http1 = <String, HttpHeaders>{};
    var http2 = <String, Map<String, List<String>>>{};
    await capture(() async {
      var running = runner.run([
        '-j', '1', '-p', '0', '--http2', //
        '--certificate-file', 'test/dev.pem',
        '--key-file', 'test/dev.key', '--key-password', 'dartdart',
      ]);
      await printed(lines, 'listening at');
      var url = Uri.parse(
        RegExp(r'listening at (\S+)').firstMatch(plain(lines).join('\n'))![1]!,
      );
      for (var path in ['/', '/own', '/cookie']) {
        // Without ALPN, so it is served by the HTTP/1 fallback.
        var response = await (await client.getUrl(url.replace(path: path)))
            .close();
        await response.drain<void>();
        http1[path] = response.headers;
        http2[path] = await http2Headers(url, path);
      }
      runner.stop();
      await running.timeout(const Duration(seconds: 15));
    }, lines);

    // The configured headers, as defaults, less the removed one.
    expect(http1['/']!.value('x-frame-options'), isNull);
    // As one line, which dart:io sends for each header but set-cookie.
    expect(http1['/']!.value('vary'), 'accept, origin');
    expect(http1['/']!.value('cache-control'), 'no-store');
    expect(http1['/']!['set-cookie'], ['a=1', 'b=2', 'c=3; Path=/x; HttpOnly']);
    expect(http1['/']!.value('x-list'), 'a');
    expect(http1['/']!.value('x-case'), 'a, b');
    expect(http1['/']!.value('x-xss-protection'), isNull);
    expect(http1['/']!.value('x-gone'), isNull);
    expect(http2['/'], isNot(contains('x-frame-options')));
    expect(http2['/'], isNot(contains('x-gone')));
    expect(http2['/']!['vary'], ['accept, origin']);
    expect(http2['/']!['cache-control'], ['no-store']);
    // One header per cookie, as a browser needs.
    expect(http2['/']!['set-cookie'], ['a=1', 'b=2', 'c=3; Path=/x; HttpOnly']);
    expect(http2['/']!['x-list'], ['a']);
    expect(http2['/']!['x-case'], ['a, b']);

    // The handler's own headers replace them, and are not removed.
    expect(http1['/own']!.value('cache-control'), 'public');
    expect(http1['/own']!.value('x-frame-options'), 'DENY');
    // A cookie of the handler comes after the default one of its name, so
    // that it wins.
    expect(http1['/cookie']!['set-cookie']!.map(cookieName), [
      'a',
      'b',
      'c',
      'a',
    ]);
    expect(http1['/cookie']!['set-cookie']!.last, startsWith('a=5'));
    expect(http2['/cookie']!['set-cookie']!.map(cookieName), [
      'a',
      'b',
      'c',
      'a',
    ]);
    expect(http2['/cookie']!['set-cookie']!.last, startsWith('a=5'));
    expect(http2['/own']!['cache-control'], ['public']);
    expect(http2['/own']!['x-frame-options'], ['DENY']);
  });

  test('without --http2, the response headers apply as the tests of --http2 '
      'expect', () async {
    var runner = Runner(
      'app',
      headersApp,
      removeResponseHeaders: testRemovedHeaders,
      responseHeaders: testResponseHeaders,
    );
    var lines = <String>[];
    var client = HttpClient();
    addTearDown(() => client.close(force: true));
    var http1 = <String, HttpHeaders>{};
    await capture(() async {
      var running = runner.run(['-j', '1', '-p', '0']);
      await printed(lines, 'listening at');
      var url = Uri.parse(
        RegExp(r'listening at (\S+)').firstMatch(plain(lines).join('\n'))![1]!,
      );
      for (var path in ['/', '/own', '/cookie']) {
        var response = await (await client.getUrl(url.replace(path: path)))
            .close();
        await response.drain<void>();
        http1[path] = response.headers;
      }
      runner.stop();
      await running.timeout(const Duration(seconds: 15));
    }, lines);

    expect(http1['/']!.value('x-frame-options'), isNull);
    expect(http1['/']!.value('vary'), 'accept, origin');
    expect(http1['/']!.value('cache-control'), 'no-store');
    expect(http1['/']!['set-cookie'], ['a=1', 'b=2', 'c=3; Path=/x; HttpOnly']);
    expect(http1['/']!.value('x-list'), 'a');
    expect(http1['/']!.value('x-case'), 'a, b');
    expect(http1['/']!.value('x-xss-protection'), isNull);
    expect(http1['/']!.value('x-gone'), isNull);
    // A cookie of the handler comes after the default one of its name, so
    // that it wins.
    expect(http1['/cookie']!['set-cookie']!.map(cookieName), [
      'a',
      'b',
      'c',
      'a',
    ]);
    expect(http1['/cookie']!['set-cookie']!.last, startsWith('a=5'));
    expect(http1['/own']!.value('cache-control'), 'public');
    expect(http1['/own']!.value('x-frame-options'), 'DENY');
  });

  test('a failed run does not stop spawnIsolate instances', () async {
    var runner = Runner('app', firstFailsApp);
    var lines = <String>[];
    var adapter = IsolateAdapter();
    var server = Server([adapter]);
    await capture(() async {
      server
        ..registerClient(const ClientInfo('client0'))
        ..registerClient(const ClientInfo('client5'))
        ..start();
      var spawned = runner.spawnIsolate(
        5,
        RunnerOptions(port: 0),
        adapter.receivePort.sendPort,
      );
      await printed(lines, 'listening at');
      await runner.run(['-j', '1', '-p', '0']);
      expect(exitCode, isNot(0));
      await Future.delayed(const Duration(milliseconds: 500));
      expect(lines.where((l) => l.contains('closed instance')), isEmpty);
      runner.stop();
      await spawned.timeout(const Duration(seconds: 15));
    }, lines);
    await server.close();
    expect(lines.where((l) => l.contains('closed instance')), hasLength(1));
    exitCode = 0;
  });

  test('stop while nothing runs does not stop a later spawnIsolate', () async {
    var runner = Runner('app', closingApp)..stop();
    var lines = <String>[];
    var adapter = IsolateAdapter();
    var server = Server([adapter]);
    await capture(() async {
      server
        ..registerClient(const ClientInfo('client0'))
        ..start();
      var done = runner.spawnIsolate(
        0,
        RunnerOptions(port: 0),
        adapter.receivePort.sendPort,
      );
      await printed(lines, 'listening at');
      runner.stop();
      await done.timeout(const Duration(seconds: 15));
    }, lines);
    await server.close();
    expect(lines.where((l) => l.contains('closed the database')), hasLength(1));
  });

  group('stop', () {
    late Server server;
    late IsolateAdapter adapter;

    setUp(() {
      adapter = IsolateAdapter();
      server = Server([adapter])
        ..registerClient(const ClientInfo('client0'))
        ..registerClient(const ClientInfo('client5'))
        ..start();
    });

    tearDown(() => server.close());

    Future spawn(Runner runner) => runner.spawnIsolate(
      5,
      RunnerOptions(port: 0),
      adapter.receivePort.sendPort,
    );

    test('while nothing runs, then spawnIsolate and run: stop still closes '
        'both', () async {
      var runner = Runner('app', closingApp)..stop();
      var lines = <String>[];
      await capture(() async {
        var spawned = spawn(runner);
        await printed(lines, 'listening at');
        var running = runner.run(['-j', '1', '-p', '0']);
        await printed(lines, 'listening at', count: 2);
        runner.stop();
        await running.timeout(const Duration(seconds: 15));
        await spawned.timeout(const Duration(seconds: 15));
      }, lines);
      expect(
        lines.where((l) => l.contains('closed the database')),
        hasLength(2),
      );
    });

    test(
      'while nothing runs applies to the next run, not after --help',
      () async {
        var runner = Runner('app', closingApp)..stop();
        var (lines, _) = await capture(() async {
          await runner.run(['--help']);
          await runner
              .run(['-j', '1', '-p', '0'])
              .timeout(const Duration(seconds: 5));
        });
        expect(lines.where((l) => l.contains('listening at')), isEmpty);
      },
    );

    test('of a spawnIsolate instance does not stop a run started while it '
        'closes', () async {
      var runner = Runner('app', closingApp);
      var lines = <String>[];
      await capture(() async {
        var spawned = spawn(runner);
        await printed(lines, 'listening at');
        runner.stop();
        // Before the instance has closed.
        var running = runner.run(['-j', '1', '-p', '0']);
        await spawned.timeout(const Duration(seconds: 15));
        await printed(lines, 'listening at', count: 2);
        runner.stop();
        await running.timeout(const Duration(seconds: 15));
      }, lines);
      expect(
        lines.where((l) => l.contains('closed the database')),
        hasLength(2),
      );
    });
  });

  test('stop before run starts no instances', () async {
    var runner = Runner('app', closingApp)..stop();
    var (lines, _) = await capture(
      () => runner
          .run(['-j', '1', '-p', '0'])
          .timeout(const Duration(seconds: 5)),
    );
    expect(lines.where((l) => l.contains('listening at')), isEmpty);
  });

  test('spawnIsolate instances are closed by stop', () async {
    var runner = Runner('app', closingApp);
    var lines = <String>[];
    var adapter = IsolateAdapter();
    var server = Server([adapter]);
    await capture(() async {
      server
        ..registerClient(const ClientInfo('client0'))
        ..start();
      var done = runner.spawnIsolate(
        0,
        RunnerOptions(port: 0),
        adapter.receivePort.sendPort,
      );
      await printed(lines, 'listening at');
      runner.stop();
      await done.timeout(const Duration(seconds: 15));
    }, lines);
    await server.close();
    expect(lines.where((l) => l.contains('closed the database')), hasLength(1));
  });

  test(
    'spawnIsolate instances started before run are closed by stop',
    () async {
      var runner = Runner('app', closingApp);
      var lines = <String>[];
      var adapter = IsolateAdapter();
      var server = Server([adapter]);
      await capture(() async {
        server
          ..registerClient(const ClientInfo('client0'))
          ..start();
        var spawned = runner.spawnIsolate(
          0,
          RunnerOptions(port: 0),
          adapter.receivePort.sendPort,
        );
        await printed(lines, 'listening at');
        var running = runner.run(['-j', '1', '-p', '0']);
        await printed(lines, 'listening at', count: 2);
        runner.stop();
        await running.timeout(const Duration(seconds: 15));
        await spawned.timeout(const Duration(seconds: 15));
      }, lines);
      await server.close();
      expect(
        lines.where((l) => l.contains('closed the database')),
        hasLength(2),
      );
    },
  );

  test('spawnIsolate starts an instance again after stop', () async {
    var runner = Runner('app', closingApp);
    var lines = <String>[];
    var adapter = IsolateAdapter();
    var server = Server([adapter]);
    await capture(() async {
      server
        ..registerClient(const ClientInfo('client0'))
        ..start();
      for (var round = 1; round <= 2; round++) {
        var done = runner.spawnIsolate(
          0,
          RunnerOptions(port: 0),
          adapter.receivePort.sendPort,
        );
        await printed(lines, 'listening at', count: round);
        runner.stop();
        await done.timeout(const Duration(seconds: 15));
      }
    }, lines);
    await server.close();
    expect(lines.where((l) => l.contains('closed the database')), hasLength(2));
  });

  test(
    'an isolate that fails to spawn again after a start is respawned',
    () async {
      var runner = Runner('app', crashingApp);
      var lines = <String>[];
      var adapter = IsolateAdapter();
      var server = Server([adapter]);
      var options = RunnerOptions(port: 0);
      var unsendable = ReceivePort();
      addTearDown(unsendable.close);
      await capture(() async {
        server
          ..registerClient(const ClientInfo('client0'))
          ..start();
        var done = runner.spawnIsolate(
          0,
          options,
          adapter.receivePort.sendPort,
        );
        await printed(lines, 'listening at');
        // Options that cannot be sent to an isolate, so that Isolate.spawn
        // fails when the instance, which crashes, is respawned.
        options.responseHeaders['x-unsendable'] = unsendable;
        await printed(lines, 'failed to start again');
        options.responseHeaders.remove('x-unsendable');
        await printed(lines, 'listening at', count: 2);
        runner.stop();
        // Not with a StartupException, which would end the runner.
        await done.timeout(const Duration(seconds: 15));
      }, lines);
      await server.close();
      // Logged with the error of Isolate.spawn.
      expect(
        plain(lines).where((l) => l.contains('Illegal argument in isolate')),
        isNotEmpty,
      );
    },
  );

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

  test('the process exits once its instances have closed', () async {
    var process = await Process.start(Platform.resolvedExecutable, [
      'test/stop_app.dart',
      '-j',
      '1',
      '-p',
      '0',
    ]);
    addTearDown(process.kill);
    var out = <String>[];
    process.stdout
        .transform(const SystemEncoding().decoder)
        // Lines, as a chunk may end within one.
        .transform(const LineSplitter())
        .listen((text) => out.add(text));
    process.stderr.drain<void>();
    await printed(out, 'listening at', timeout: const Duration(seconds: 60));

    var stopwatch = Stopwatch()..start();
    process.kill(ProcessSignal.sigint);
    var code = await process.exitCode.timeout(const Duration(seconds: 40));
    // Not after its shutdownTimeout of 30 seconds, which a kill timer that
    // was not cancelled made it wait for.
    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 10)));
    expect(code, 0);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('one signal closes two runs in progress gracefully', () async {
    var process = await Process.start(Platform.resolvedExecutable, [
      'test/two_runs_app.dart',
      '-j',
      '1',
      '-p',
      '0',
    ]);
    addTearDown(process.kill);
    var out = <String>[];
    process.stdout
        .transform(const SystemEncoding().decoder)
        .transform(const LineSplitter())
        .listen((text) => out.add(text));
    process.stderr.drain<void>();
    await printed(
      out,
      'listening at',
      count: 2,
      timeout: const Duration(seconds: 60),
    );

    process.kill(ProcessSignal.sigint);
    var code = await process.exitCode.timeout(const Duration(seconds: 30));
    // Not 70, as when the second handler took it for a second signal.
    expect(code, 0);
    expect(out.where((l) => l.contains('closed instance')), hasLength(2));
  }, timeout: const Timeout(Duration(minutes: 2)));

  test(
    'a record of an instance is printed with the time it was logged at',
    () async {
      var runner = Runner('app', laterLoggingApp);
      var lines = <String>[];
      await capture(() async {
        var running = runner.run(['-j', '1', '-p', '0']);
        await printed(lines, 'listening at');
        // Busy, so that the record logged meanwhile waits to be received.
        var busy = Stopwatch()..start();
        while (busy.elapsed < const Duration(seconds: 6)) {}
        await printed(lines, 'logged at');
        runner.stop();
        await running.timeout(const Duration(seconds: 15));
      }, lines);
      var line = plain(lines).firstWhere((l) => l.contains('logged at'));
      var printedAt = DateTime.parse(line.substring(0, 19));
      var loggedAt = DateTime.parse(line.split('logged at ').last);
      expect(printedAt.difference(loggedAt).inSeconds.abs(), lessThan(2));
    },
  );

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
