import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';
import 'dart:isolate';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_websocket/server.dart';
import 'package:charcode/ascii.dart';
import 'package:glob/glob.dart';
import 'package:belatuk_html_builder/elements.dart';
import 'package:io/ansi.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:vm_service/vm_service.dart' as vm;
import 'package:vm_service/vm_service_io.dart' as vm;
import 'package:watcher/watcher.dart';

/// A utility class that watches the filesystem for changes, and starts new instances of an Angel server.
///
/// On a change, the Dart VM's sources are reloaded (if the VM service is
/// enabled, and [hotReload]), and a new server is made by [generator]. The
/// old one is closed once the new one serves; requests that come meanwhile
/// wait for it. A server that fails to be made, or a reload that fails, is
/// logged, and the last good server goes on serving.
class HotReloader {
  final StreamController<WatchEvent> _onChange =
      StreamController<WatchEvent>.broadcast();
  final List _paths = [];
  final StringRenderer _renderer = StringRenderer(pretty: false);
  final Queue<HttpRequest> _requestQueue = Queue<HttpRequest>();
  final List<StreamSubscription> _subscriptions = [];
  HttpServer? _io;
  AngelHttp? _server;
  late Duration _timeout;
  vm.VmService? _client;
  String? _isolateId;
  bool _started = false, _closed = false;

  /// The reload that runs, and whether another is asked for meanwhile.
  Future<void>? _reloading;
  bool _reloadAgain = false, _reloadAgainHot = false;
  Timer? _debounceTimer;

  /// If `true` (default), then developers can `press 'r' to reload` the application on-the-fly.
  ///
  /// This option triggers printing a Flutter-like output to the terminal.
  final bool enableHotkeys;

  /// If `true` (default), and the Dart VM service is enabled
  /// (`--enable-vm-service` or `--observe`), the VM's sources are reloaded
  /// before a new server is made. Otherwise the server is only made again,
  /// of the code already loaded.
  final bool hotReload;

  /// How long file changes are gathered before they trigger one reload, as
  /// an editor's save may change several files, or one more than once.
  final Duration debounce;

  /// Invoked to load a new instance of [Angel] on file changes.
  final FutureOr<Angel> Function() generator;

  /// Fires whenever a file change. You might consider using this to trigger
  /// page reloads in a client.
  Stream<WatchEvent> get onChange => _onChange.stream;

  /// The maximum amount of time to queue incoming requests for if there is no [server] available.
  ///
  /// If the timeout expires, then the request will be immediately terminated with a `502 Bad Gateway` error.
  /// Default: `5s`
  Duration get timeout => _timeout;

  /// The host of the Dart VM service, used if the VM does not tell its URI.
  ///
  /// Default: `localhost`.
  final String vmServiceHost;

  /// The port of the Dart VM service, used if the VM does not tell its URI.
  ///
  /// Default: `8181`.
  final int vmServicePort;

  /// Initializes a hot reloader that proxies the server created by [generator].
  ///
  /// [paths] can contain [FileSystemEntity], [Uri], [String] and [Glob] only.
  /// URI's can be `package:` URI's as well. A relative path, or [Glob], is
  /// of the current working directory, as `dart run` is started in.
  HotReloader(
    this.generator,
    Iterable paths, {
    Duration? timeout,
    this.vmServiceHost = 'localhost',
    this.vmServicePort = 8181,
    this.enableHotkeys = true,
    this.hotReload = true,
    this.debounce = const Duration(milliseconds: 200),
  }) {
    _timeout = timeout ?? Duration(seconds: 5);
    _paths.addAll(paths);
  }

  /// Stops watching, closes the server and the current app, and gives the
  /// terminal back its line and echo modes.
  Future close() async {
    if (_closed) return;
    _closed = true;
    _debounceTimer?.cancel();
    for (var sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
    if (enableHotkeys && _started) {
      try {
        stdin.echoMode = stdin.lineMode = true;
      } catch (_) {
        // Not a terminal.
      }
    }
    await _reloading;
    await _io?.close(force: true);
    var server = _server;
    _server = null;
    if (server != null) await _killServer(server);
    await _client?.dispose();
    await _onChange.close();
  }

  void sendError(HttpRequest request, int status, String title_, e) {
    var doc = html(
      lang: 'en',
      c: [
        head(
          c: [
            meta(
              name: 'viewport',
              content: 'width=device-width, initial-scale=1',
            ),
            title(c: [text(title_)]),
          ],
        ),
        body(
          c: [
            h1(c: [text(title_)]),
            i(c: [text(e.toString())]),
          ],
        ),
      ],
    );

    var response = request.response;
    response.statusCode = status;
    response.headers
      ..contentType = ContentType.html
      ..set(HttpHeaders.serverHeader, 'angel3');

    if (request.headers
            .value(HttpHeaders.acceptEncodingHeader)
            ?.toLowerCase()
            .contains('gzip') ==
        true) {
      response
        ..headers.set(HttpHeaders.contentEncodingHeader, 'gzip')
        ..add(gzip.encode(utf8.encode(_renderer.render(doc))));
    } else {
      response.write(_renderer.render(doc));
    }
    response.close();
  }

  Future _handle(HttpRequest request) {
    return _server!.handleRequest(request);
  }

  /// Handles [request] with the current server, or, while there is none (as
  /// during a reload), once there is one, for at most [timeout].
  Future handleRequest(HttpRequest request) async {
    if (_server != null) {
      return await _handle(request);
    }
    _requestQueue.add(request);
    Timer(timeout, () {
      if (_requestQueue.remove(request)) {
        sendError(
          request,
          HttpStatus.badGateway,
          '502 Bad Gateway',
          'Request timed out after ${timeout.inMilliseconds}ms.',
        );
      }
    });
  }

  /// Handles the requests queued while there was no server, all at once.
  void _flushQueue() {
    while (_requestQueue.isNotEmpty && _server != null) {
      unawaited(_handle(_requestQueue.removeFirst()));
    }
  }

  Logger? get _appLogger => _server?.app.logger;

  Future<AngelHttp> _generateServer() async {
    var s = await generator();
    await Future.forEach(s.startupHooks, s.configure);
    s.optimizeForProduction();
    return AngelHttp.custom(s, startShared);
  }

  void _logWarning(String msg, [Object? error, StackTrace? stackTrace]) {
    if (_appLogger != null) {
      _appLogger?.warning(msg, error, stackTrace);
    } else {
      print(yellow.wrap('WARNING: $msg${error == null ? '' : '\n$error'}'));
    }
  }

  void _logInfo(String msg) {
    if (_appLogger != null) {
      _appLogger?.info(msg);
    } else {
      print(lightGray.wrap(msg));
    }
  }

  /// Whether the Dart VM was started with its service enabled.
  static bool get _vmServiceEnabled => Platform.executableArguments.any(
    (arg) =>
        arg.startsWith('--observe') || arg.startsWith('--enable-vm-service'),
  );

  /// Starts listening to requests and filesystem events.
  ///
  /// Throws a [StateError] if it has already started, or been closed.
  Future<HttpServer> startServer([
    String address = '127.0.0.1',
    int port = 3000,
  ]) async {
    if (_started || _closed) {
      throw StateError('The HotReloader has already been started.');
    }
    _started = true;
    _server = await _generateServer();

    if (_paths.isEmpty) {
      _logWarning(
        'You have instantiated a HotReloader without providing any filesystem paths to watch.',
      );
    }

    var isHot = hotReload && _vmServiceEnabled;
    if (hotReload && !isHot) {
      _logWarning(
        'You have instantiated a HotReloader without passing `--enable-vm-service` or `--observe` to the Dart VM. Hot reloading will be disabled: on a change, the server is only made again, of the code already loaded.',
      );
    }
    if (isHot) isHot = await _connectToVm();

    _subscriptions.add(
      _onChange.stream.listen((e) => _scheduleReload(e.path, hot: isHot)),
    );
    await _listenToFilesystem();

    var server = _io = await HttpServer.bind(address, port);
    _subscriptions.add(server.listen(handleRequest));
    _flushQueue();

    if (enableHotkeys) await _listenToHotkeys(server, isHot);

    return server;
  }

  /// Connects to the VM service, of the isolate this runs in; whether it
  /// could.
  Future<bool> _connectToVm() async {
    try {
      var info = await dev.Service.getInfo();
      var uri =
          info.serverUri ??
          Uri(scheme: 'http', host: vmServiceHost, port: vmServicePort);
      uri = uri.replace(
        scheme: uri.scheme == 'https' ? 'wss' : 'ws',
        path: p.url.join(uri.path, 'ws'),
      );
      var client = _client = await vm.vmServiceConnectUri(uri.toString());
      _isolateId = dev.Service.getIsolateId(Isolate.current);
      var isolateId = _isolateId;
      if (isolateId == null) {
        _logWarning('Hot reload disabled: the id of this isolate is unknown.');
        return false;
      }
      await client.setIsolatePauseMode(isolateId, exceptionPauseMode: 'None');
      return true;
    } catch (e, st) {
      _logWarning(
        'Hot reload disabled: the VM service could not be reached.',
        e,
        st,
      );
      return false;
    }
  }

  Future<void> _listenToHotkeys(HttpServer server, bool isHot) async {
    var serverUri = Uri(
      scheme: 'http',
      host: server.address.address,
      port: server.port,
    );

    Uri? observatoryUri;
    if (isHot) {
      observatoryUri = await dev.Service.getInfo().then((i) => i.serverUri);
    }

    print(
      styleBold.wrap(
        '\n🔥  To hot reload changes while running, press "r". To hot restart (and rebuild state), press "R".',
      ),
    );
    stdout.write('Your server is listening at: ');
    print(wrapWith('$serverUri', [cyan, styleUnderlined]));

    if (isHot) {
      stdout.write(
        'An Observatory debugger and profiler on ${Platform.operatingSystem} is available at: ',
      );

      print(wrapWith('$observatoryUri', [cyan, styleUnderlined]));
    } else {
      stdout.write(
        'The observatory debugger and profiler are not available.\n',
      );
    }
    print('For a more detailed help message, press "h". To quit, press "q".\n');

    if (_paths.isNotEmpty) {
      print(
        darkGray.wrap(
          'Changes to the following path(s) will also trigger a hot reload:',
        ),
      );

      for (var p in _paths) {
        print(darkGray.wrap('  * $p'));
      }

      stdout.writeln();
    }

    try {
      stdin.lineMode = stdin.echoMode = false;
    } catch (_) {
      // Not a terminal.
    }

    try {
      _subscriptions.add(
        stdin.expand((l) => l).listen((ch) async {
          if (ch == $r) {
            await reload(reason: '[manual-reload]', hot: isHot);
          } else if (ch == $R) {
            _logInfo('Manually restarting server...\n');
            await reload(reason: '[manual-restart]', hot: false);
          } else if (ch == $q) {
            await close();
            exit(0);
          } else if (ch == $h) {
            print(
              'Press "r" to hot reload the Dart VM, and restart the active server.',
            );
            print(
              'Press "R" to restart the server, WITHOUT a hot reload of the VM.',
            );
            print('Press "q" to quit the server.');
            print('Press "h" to display this help information.');
            stdout.writeln();
          }
        }),
      );
    } on StateError {
      // stdin is listened to elsewhere.
    }
  }

  Future<void> _listenToFilesystem() async {
    for (var path in _paths) {
      if (path is String) {
        await _listenToStat(path);
      } else if (path is Glob) {
        await _listenToGlob(path);
      } else if (path is FileSystemEntity) {
        await _listenToStat(path.path);
      } else if (path is Uri) {
        if (path.scheme == 'package') {
          var uri = await Isolate.resolvePackageUri(path);
          await _listenToStat((uri ?? path).toFilePath());
        } else {
          await _listenToStat(path.toFilePath());
        }
      } else {
        throw ArgumentError(
          'Hot reload paths must be a FileSystemEntity, a Uri, a String or a Glob. You provided: $path',
        );
      }
    }
  }

  /// Watches the current directory for files that [glob] matches, including
  /// files created after the start.
  Future<void> _listenToGlob(Glob glob) async {
    var root = Directory.current.path;
    var watcher = DirectoryWatcher(root);
    _subscriptions.add(
      watcher.events.listen(
        (e) {
          if (glob.matches(p.relative(e.path, from: root))) _onChange.add(e);
        },
        onError: (Object e) {
          _logWarning('Could not listen to file changes of $glob: $e');
        },
      ),
    );
    await watcher.ready;
  }

  Future<void> _listenToStat(String path) async {
    try {
      var stat = await FileStat.stat(path);
      if (stat.type == FileSystemEntityType.link) {
        return await _listenToStat(await Link(path).resolveSymbolicLinks());
      }
      if (stat.type == FileSystemEntityType.file ||
          stat.type == FileSystemEntityType.directory) {
        var watcher = Watcher(path);
        _subscriptions.add(
          watcher.events.listen(
            _onChange.add,
            onError: (Object e) {
              _logWarning('Could not listen to file changes at $path: $e');
            },
          ),
        );
        // Changes are seen once it is ready.
        await watcher.ready;
        return;
      }
    } on FileSystemException {
      // As one that does not exist.
    }
    _logWarning(
      'Unable to watch path "$path" from working directory "${Directory.current.path}". Please ensure that it exists.',
    );
  }

  /// Closes [server]: its WebSockets, its shutdown hooks, and its app.
  Future<void> _killServer(AngelHttp server) async {
    var app = server.app;
    try {
      if (app.container.has<AngelWebSocket>()) {
        var ws = app.container.make<AngelWebSocket>();
        for (var client in ws.clients) {
          try {
            await client.close();
          } catch (e) {
            _logWarning(
              'Couldn\'t close WebSocket from session #${client.request.session?.id}: $e',
            );
          }
        }
      }
      // As a driver closes it: its shutdown hooks, then the app.
      await Future.forEach(app.shutdownHooks, app.configure);
      await app.close();
    } catch (e, st) {
      _logWarning('The old server could not be closed.', e, st);
    } finally {
      app.logger.clearListeners();
    }
  }

  /// Reloads after [debounce], as one reload of the changes until then.
  void _scheduleReload(String reason, {required bool hot}) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () => reload(reason: reason, hot: hot));
  }

  /// Reloads the VM's sources, if [hot], and makes a new server of
  /// [generator], which replaces the current one, once made.
  ///
  /// Reloads run one at a time: one asked for while another runs runs once
  /// it is done, as one reload of all that were asked for meanwhile. Returns
  /// once the server is replaced, or, if it failed, logged.
  Future<void> reload({String reason = '[reload]', bool hot = false}) async {
    if (_closed) return;
    var running = _reloading;
    if (running != null) {
      _reloadAgain = true;
      _reloadAgainHot = _reloadAgainHot || hot;
      return running;
    }
    var done = _reloading = _reloadNow(reason, hot);
    try {
      await done;
    } finally {
      _reloading = null;
    }
    if (_reloadAgain && !_closed) {
      var again = _reloadAgainHot;
      _reloadAgain = _reloadAgainHot = false;
      await reload(reason: '[changes during the reload]', hot: again);
    }
  }

  Future<void> _reloadNow(String reason, bool hot) async {
    _logInfo('$reason changed. Reloading server...\n');
    var old = _server;
    // Requests wait for the new server.
    _server = null;

    AngelHttp next;
    try {
      if (hot) await _reloadSources();
      next = await _generateServer();
    } catch (e, st) {
      _server = old;
      _logWarning(
        'The server could not be reloaded; the last one goes on serving.',
        e,
        st,
      );
      _flushQueue();
      return;
    }

    _server = next;
    _flushQueue();
    if (old != null) await _killServer(old);
  }

  /// Reloads the VM's sources, or warns that it could not.
  Future<void> _reloadSources() async {
    var client = _client, isolateId = _isolateId;
    if (client == null || isolateId == null) {
      _logWarning('Hot reload failed - isolate id does not exist.');
      return;
    }
    var report = await client.reloadSources(isolateId);
    if (report.success != true) {
      var notices = report.json?['notices'];
      _logWarning(
        'Hot reload failed - perhaps some sources have not been generated yet.'
        '${notices == null ? '' : '\n$notices'}',
      );
    }
  }
}
