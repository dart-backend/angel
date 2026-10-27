import 'dart:async';
import 'dart:io';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_hot/angel3_hot.dart';
import 'package:glob/glob.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:test/test.dart';

/// A resource of an app, closed by its shutdown hook.
class Db {
  bool open = true;
}

/// A generator of apps, each with a [Db], whose `/slow` route answers after
/// [delay], and that waits for [gate] before making one, if set.
class Apps {
  final List<Angel> made = [];
  final List<Db> dbs = [];
  final List<List<String>> logs = [];
  Duration delay = const Duration(milliseconds: 300);
  Completer<void>? gate;

  Future<Angel> generate() async {
    await gate?.future;
    var n = made.length + 1;
    var db = Db();
    var log = <String>[];
    var app = Angel()
      ..logger = (Logger.detached('app$n')
        ..onRecord.listen((r) => log.add(r.message)));
    app.shutdownHooks.add((_) => db.open = false);
    app.get('/', (req, res) => 'v$n');
    app.get('/slow', (req, res) async {
      await Future.delayed(delay);
      return db.open ? 'v$n open' : 'v$n CLOSED';
    });
    made.add(app);
    dbs.add(db);
    logs.add(log);
    return app;
  }
}

void main() {
  late Apps apps;

  Future<(HotReloader, HttpServer)> start({
    Duration grace = const Duration(seconds: 10),
    List paths = const [],
  }) async {
    var hot = HotReloader(
      apps.generate,
      paths,
      hotReload: false,
      enableHotkeys: false,
      shutdownGracePeriod: grace,
      debounce: const Duration(milliseconds: 100),
    );
    return (hot, await hot.startServer('127.0.0.1', 0));
  }

  setUp(() => apps = Apps());

  Uri url(HttpServer server, String path) =>
      Uri.parse('http://127.0.0.1:${server.port}$path');

  test('a request in flight is answered before its server closes', () async {
    var (hot, server) = await start();
    addTearDown(hot.close);
    var response = http.get(url(server, '/slow'));
    await Future.delayed(const Duration(milliseconds: 50));
    await hot.reload();
    expect((await response).body, '"v1 open"');
    // And then it closes.
    await Future.delayed(const Duration(milliseconds: 50));
    expect(apps.dbs.first.open, isFalse);
  });

  test('a server is closed after its grace period anyway', () async {
    apps.delay = const Duration(seconds: 1);
    var (hot, server) = await start(grace: const Duration(milliseconds: 100));
    addTearDown(hot.close);
    var response = http.get(url(server, '/slow'));
    await Future.delayed(const Duration(milliseconds: 50));
    await hot.reload();
    expect(apps.dbs.first.open, isFalse);
    expect((await response).body, '"v1 CLOSED"');
  });

  test('close answers the requests that wait for a reload with 503', () async {
    var (hot, server) = await start();
    apps.gate = Completer<void>();
    unawaited(hot.reload());
    var response = http.get(url(server, '/'));
    await Future.delayed(const Duration(milliseconds: 100));
    var closing = hot.close();
    expect((await response).statusCode, 503);
    apps.gate!.complete();
    await closing;
  });

  test('a reload asked for during one returns once it has run', () async {
    var (hot, server) = await start();
    addTearDown(hot.close);
    apps.gate = Completer<void>();
    var first = hot.reload();
    var second = hot.reload();
    apps.gate!.complete();
    await second;
    // Of the reload asked for second, which ran after the first.
    expect((await http.get(url(server, '/'))).body, '"v3"');
    await first;
  });

  test('a reload logs to the logger of the server it replaces', () async {
    var (hot, _) = await start();
    addTearDown(hot.close);
    await hot.reload(reason: 'test.dart');
    expect(apps.logs.first, contains(contains('test.dart changed')));
  });

  test('a Glob watches the directory it names', () async {
    var cwd = Directory.current;
    var tmp = Directory.systemTemp.createTempSync('angel3_hot_glob');
    Directory('${tmp.path}/views').createSync();
    Directory('${tmp.path}/other').createSync();
    Directory.current = tmp;
    addTearDown(() {
      Directory.current = cwd;
      tmp.deleteSync(recursive: true);
    });

    var (hot, _) = await start(paths: [Glob('views/**.html')]);
    addTearDown(hot.close);
    File('${tmp.path}/other/a.html').writeAsStringSync('no');
    await Future.delayed(const Duration(milliseconds: 500));
    expect(apps.made, hasLength(1));

    // A file created after the start.
    File('${tmp.path}/views/b.html').writeAsStringSync('yes');
    for (var i = 0; i < 50 && apps.made.length < 2; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    expect(apps.made, hasLength(2));
  });

  test('paths of another type are refused when it is made', () {
    expect(
      () => HotReloader(apps.generate, [42], enableHotkeys: false),
      throwsArgumentError,
    );
  });
}
