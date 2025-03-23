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
import 'package:glob/list_local_fs.dart';
import 'package:belatuk_html_builder/elements.dart';
import 'package:io/ansi.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:vm_service/vm_service.dart' as vm;
import 'package:vm_service/vm_service_io.dart' as vm;
import 'package:watcher/watcher.dart';

/// A utility class that watches the filesystem for changes, and starts new instances of an Angel server.
class HotReloader {
  final StreamController<WatchEvent> _onChange =
      StreamController<WatchEvent>.broadcast();
  final List _paths = [];
  final StringRenderer _renderer = StringRenderer(pretty: false);
  final Queue<HttpRequest> _requestQueue = Queue<HttpRequest>();
  late HttpServer _io;
  AngelHttp? _server;
  late Duration _timeout;
  late vm.VmService _client;
  vm.VM? _vmachine;
  vm.IsolateRef? _mainIsolate;

  /// If `true` (default), then developers can `press 'r' to reload` the application on-the-fly.
  ///
  /// This option triggers printing a Flutter-like output to the terminal.
  final bool enableHotkeys;

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

  /// The Dart VM service host.
  ///
  /// Default: `localhost`.
  final String vmServiceHost;

  /// The port to connect to the Dart VM service.
  ///
  /// Default: `8181`.
  final int vmServicePort;

  /// Initializes a hot reloader that proxies the server created by [generator].
  ///
  /// [paths] can contain [FileSystemEntity], [Uri], [String] and [Glob] only.
  /// URI's can be `package:` URI's as well.
  HotReloader(this.generator, Iterable paths,
      {Duration? timeout,
      this.vmServiceHost = 'localhost',
      this.vmServicePort = 8181,
      this.enableHotkeys = true}) {
    _timeout = timeout ?? Duration(seconds: 5);
    _paths.addAll(paths);
  }

  Future close() async {
    await _io.close(force: true);
    await _onChange.close();
  }

  void sendError(HttpRequest request, int status, String title_, e) {
    var doc = html(lang: 'en', c: [
      head(c: [
        meta(name: 'viewport', content: 'width=device-width, initial-scale=1'),
        title(c: [text(title_)])
      ]),
      body(c: [
        h1(c: [text(title_)]),
        i(c: [text(e.toString())])
      ])
    ]);

    var response = request.response;
    response.statusCode = HttpStatus.badGateway;
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

  Future handleRequest(HttpRequest request) async {
    if (_server != null) {
      return await _handle(request);
      //} else if (timeout == null) {
      //  _requestQueue.add(request);
    } else {
      _requestQueue.add(request);
      Timer(timeout, () {
        if (_requestQueue.remove(request)) {
          // Send 502 response
          sendError(request, HttpStatus.badGateway, '502 Bad Gateway',
              'Request timed out after ${timeout.inMilliseconds}ms.');
        }
      });
    }
  }

  Logger? get _appLogger => _server?.app.logger;

  Future<AngelHttp> _generateServer() async {
    var s = await generator();
    await Future.forEach(s.startupHooks, s.configure);
    s.optimizeForProduction();
    return AngelHttp.custom(s, startShared);
  }

  void _logWarning(String msg) {
    if (_appLogger != null) {
      _appLogger?.warning(msg);
    } else {
      print(yellow.wrap('WARNING: $msg'));
    }
  }

  void _logInfo(String msg) {
    if (_appLogger != null) {
      _appLogger?.info(msg);
    } else {
      print(lightGray.wrap(msg));
    }
  }

  /// Starts listening to requests and filesystem events.
  Future<HttpServer> startServer(
      [String address = '127.0.0.1', int port = 3000]) async {
    var isHot = true;
    _server = await _generateServer();

    if (_paths.isNotEmpty != true) {
      _logWarning(
          'You have instantiated a HotReloader without providing any filesystem paths to watch.');
    }

    bool sw(String s) {
      return Platform.executableArguments.any((ss) => ss.startsWith(s));
    }

    if (!sw('--observe') && !sw('--enable-vm-service')) {
      _logWarning(
          'You have instantiated a HotReloader without passing `--enable-vm-service` or `--observe` to the Dart VM. Hot reloading will be disabled.');
      isHot = false;
    } else {
      var info = await dev.Service.getInfo();
      var uri = info.serverUri!;
      uri = uri.replace(path: p.join(uri.path, 'ws'));
      if (uri.scheme == 'https') {
        uri = uri.replace(scheme: 'wss');
      } else {
        uri = uri.replace(scheme: 'ws');
      }
      _client = await vm.vmServiceConnectUri(uri.toString());
      _vmachine ??= await _client.getVM();
      _mainIsolate ??= _vmachine?.isolates?.first;

      if (_vmachine != null) {
        for (var isolate in _vmachine?.isolates ?? <vm.IsolateRef>[]) {
          var isolateId = isolate.id;
          if (isolateId != null) {
            await _client.setIsolatePauseMode(isolateId,
                exceptionPauseMode: 'None');
          }
        }
      }

      await _listenToFilesystem();
    }

    _onChange.stream
        //.transform( _Debounce( Duration(seconds: 1)))
        .listen(_handleWatchEvent);

    while (_requestQueue.isNotEmpty) {
      await _handle(_requestQueue.removeFirst());
    }
    var server = _io = await HttpServer.bind(address, port);
    //server.defaultResponseHeaders();
    server.listen(handleRequest);

    // Print a Flutter-like prompt...
    if (enableHotkeys) {
      var serverUri =
          Uri(scheme: 'http', host: server.address.address, port: server.port);

      Uri? observatoryUri;
      if (isHot) {
        observatoryUri = await dev.Service.getInfo().then((i) => i.serverUri);
      }

      print(styleBold.wrap(
          '\n🔥  To hot reload changes while running, press "r". To hot restart (and rebuild state), press "R".'));
      stdout.write('Your server is listening at: ');
      print(wrapWith('$serverUri', [cyan, styleUnderlined]));

      if (isHot) {
        stdout.write(
            'An Observatory debugger and profiler on ${Platform.operatingSystem} is available at: ');

        print(wrapWith('$observatoryUri', [cyan, styleUnderlined]));
      } else {
        stdout.write(
            'The observatory debugger and profiler are not available.\n');
      }
      print(
          'For a more detailed help message, press "h". To quit, press "q".\n');

      if (_paths.isNotEmpty) {
        print(darkGray.wrap(
            'Changes to the following path(s) will also trigger a hot reload:'));

        for (var p in _paths) {
          print(darkGray.wrap('  * $p'));
        }

        stdout.writeln();
      }

      // Listen for hotkeys
      try {
        stdin.lineMode = stdin.echoMode = false;
      } catch (_) {}

      late StreamSubscription<int> sub;

      try {
        sub = stdin.expand((l) => l).listen((ch) async {
          if (ch == $r) {
            _handleWatchEvent(
                WatchEvent(ChangeType.MODIFY, '[manual-reload]'), isHot);
          }
          if (ch == $R) {
            _logInfo('Manually restarting server...\n');
            await _killServer();
            await _server?.close();
            var addr = _io.address.address;
            var port = _io.port;
            await _io.close(force: true);
            await startServer(addr, port);
          } else if (ch == $q) {
            stdin.echoMode = stdin.lineMode = true;
            await close();
            await sub.cancel();
            exit(0);
          } else if (ch == $h) {
            print(
                'Press "r" to hot reload the Dart VM, and restart the active server.');
            print(
                'Press "R" to restart the server, WITHOUT a hot reload of the VM.');
            print('Press "q" to quit the server.');
            print('Press "h" to display this help information.');
            stdout.writeln();
          }
        });
      } catch (_) {}
    }

    return server;
  }

  Future<void> _listenToFilesystem() async {
    for (var path in _paths) {
      if (path is String) {
        await _listenToStat(path);
      } else if (path is Glob) {
        await for (var entity in path.list()) {
          await _listenToStat(entity.path);
        }
      } else if (path is FileSystemEntity) {
        await _listenToStat(path.path);
      } else if (path is Uri) {
        if (path.scheme == 'package') {
          var uri = await Isolate.resolvePackageUri(path);
          if (uri != null) {
            await _listenToStat(uri.toFilePath());
          } else {
            await _listenToStat(path.toFilePath());
          }
        } else {
          await _listenToStat(path.toFilePath());
        }
      } else {
        throw ArgumentError(
            'Hot reload paths must be a FileSystemEntity, a Uri, a String or a Glob. You provided: $path');
      }
    }
  }

  Future<void> _listenToStat(String path) async {
    Future listen() async {
      try {
        var stat = await FileStat.stat(path);
        if (stat.type == FileSystemEntityType.link) {
          var lnk = Link(path);
          var p = await lnk.resolveSymbolicLinks();
          return await _listenToStat(p);
        } else if (stat.type == FileSystemEntityType.file) {
          var file = File(path);
          if (!await file.exists()) return null;
        } else if (stat.type == FileSystemEntityType.directory) {
          var dir = Directory(path);
          if (!await dir.exists()) return null;
        } else {
          return null;
        }

        var watcher = Watcher(path);

        watcher.events.listen(_onChange.add, onError: (e) {
          _logWarning('Could not listen to file changes at $path: $e');
        });

        // print('Listening for file changes at ${path}...');
        return true;
      } catch (e) {
        if (e is! FileSystemException) rethrow;
      }
    }

    var r = await listen();

    if (r == null) {
      _logWarning(
          'Unable to watch path "$path" from working directory "${Directory.current.path}". Please ensure that it exists.');
    }
  }

  Future _killServer() async {
    if (_server != null) {
      // Do this asynchronously, because we really don't care about the old server anymore.
      scheduleMicrotask(() async {
        // Disconnect active WebSockets
        try {
          var ws = _server?.app.container.make<AngelWebSocket>();

          if (ws != null) {
            for (var client in ws.clients) {
              try {
                await client.close();
              } catch (e) {
                _logWarning(
                    'Couldn\'t close WebSocket from session #${client.request.session?.id}: $e');
              }
            }
          }

          // await Future.forEach(
          //     _server.app.shutdownHooks, _server.app.configure);
          await _server?.app.close();
          _server?.app.logger.clearListeners();
        } catch (_) {
          // Fail silently...
        }
      });
    }
  }

  void _handleWatchEvent(WatchEvent e, [bool hot = true]) async {
    _logInfo('${e.path} changed. Reloading server...\n');
    await _killServer();
    _server = null;

    if (hot) {
      var mainIsolateId = _mainIsolate?.id;
      if (mainIsolateId != null) {
        var report = await _client.reloadSources(mainIsolateId);

        if (report.success != null) {
          _logWarning(
              'Hot reload failed - perhaps some sources have not been generated yet.');
        }
      } else {
        _logWarning('Hot reload failed - isolate id does not exist.');
      }
    }

    var s = await _generateServer();
    _server = s;
    while (_requestQueue.isNotEmpty) {
      await _handle(_requestQueue.removeFirst());
    }
  }
}

/*
class _Debounce<S> extends StreamTransformerBase<S, S> {
  final Duration _delay;

  const _Debounce(this._delay);

  Stream<S> bind(Stream<S> stream) {
    var initial = DateTime.now();
    var next = initial.subtract(this._delay);
    return stream.where((S data) {
      var now = DateTime.now();
      if (now.isAfter(next)) {
        next = now.add(this._delay);
        return true;
      } else {
        return false;
      }
    });
  }
}
*/
