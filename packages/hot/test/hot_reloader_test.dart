import 'dart:async';
import 'dart:io';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_hot/angel3_hot.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

/// The apps a test's generator made, in order, and whether each is closed.
class Apps {
  final List<Angel> made = [];
  final Set<Angel> closed = {};
  int version = 0;

  /// Throws instead of making an app, while set.
  Object? failWith;

  /// Waits for this before making an app, if set.
  Completer<void>? gate;

  Future<Angel> generate() async {
    await gate?.future;
    var error = failWith;
    if (error != null) throw error;
    var v = ++version;
    var app = Angel();
    app.get('/', (req, res) => 'v$v');
    app.shutdownHooks.add((app) => closed.add(app));
    made.add(app);
    return app;
  }
}

void main() {
  late Apps apps;
  late HotReloader hot;
  late HttpServer server;
  late Directory dir;

  setUp(() async {
    apps = Apps();
    dir = Directory.systemTemp.createTempSync('angel3_hot');
    File('${dir.path}/watched.txt').writeAsStringSync('0');
    hot = HotReloader(
      apps.generate,
      [dir],
      hotReload: false,
      enableHotkeys: false,
      debounce: const Duration(milliseconds: 100),
      timeout: const Duration(seconds: 5),
    );
    server = await hot.startServer('127.0.0.1', 0);
  });

  tearDown(() async {
    await hot.close();
    dir.deleteSync(recursive: true);
  });

  Future<String> get() async =>
      (await http.get(Uri.parse('http://127.0.0.1:${server.port}/'))).body;

  test('serves the app of the generator', () async {
    expect(await get(), '"v1"');
  });

  test('a reload serves a new app, and closes the old one', () async {
    await hot.reload();
    expect(await get(), '"v2"');
    expect(apps.closed, {apps.made.first});
  });

  test(
    'a failing generator keeps the last server, and does not throw',
    () async {
      apps.failWith = StateError('a typo');
      await hot.reload();
      expect(await get(), '"v1"');
      expect(apps.closed, isEmpty);

      // And the next reload recovers.
      apps.failWith = null;
      await hot.reload();
      expect(await get(), '"v2"');
    },
  );

  test('reloads asked for during one run once, after it', () async {
    apps.gate = Completer<void>();
    var reloads = [for (var i = 0; i < 5; i++) hot.reload()];
    apps.gate!.complete();
    await Future.wait(reloads);
    await hot.reload();
    // The first, one for the four asked for during it, and the last.
    expect(apps.made, hasLength(4));
    expect(apps.closed, hasLength(3));
  });

  test('requests during a reload wait for the new server', () async {
    apps.gate = Completer<void>();
    var reloading = hot.reload();
    var response = get();
    await Future.delayed(const Duration(milliseconds: 50));
    apps.gate!.complete();
    await reloading;
    expect(await response, '"v2"');
  });

  test('changes of watched files are gathered into one reload', () async {
    var file = File('${dir.path}/watched.txt');
    for (var i = 0; i < 5; i++) {
      file.writeAsStringSync('$i');
      await Future.delayed(const Duration(milliseconds: 10));
    }
    // After the debounce and the reload.
    for (var i = 0; i < 50 && apps.made.length < 2; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    expect(apps.made.length, inInclusiveRange(2, 3));
  });

  test('startServer cannot be called again', () async {
    expect(() => hot.startServer('127.0.0.1', 0), throwsStateError);
  });

  test('close closes the current app', () async {
    await hot.close();
    expect(apps.closed, {apps.made.single});
  });
}
