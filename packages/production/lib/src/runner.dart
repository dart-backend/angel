import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:angel3_container/angel3_container.dart';
import 'package:belatuk_pub_sub/belatuk_pub_sub.dart';
import 'package:belatuk_pub_sub/isolate.dart';
import 'package:intl/intl.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_framework/http2.dart';
import 'package:args/args.dart';
import 'package:io/ansi.dart';
import 'package:io/io.dart';
import 'package:logging/logging.dart';

import 'instance_info.dart';
import 'options.dart';

/// A command-line utility for easier running of multiple instances of an Angel application.
///
/// Makes it easy to do things like configure SSL, log messages, and send messages between
/// all running instances.
///
/// An instance that fails to start ends [run] with a non-zero exit code; one
/// that crashes once started, or then fails to start again, is respawned
/// (with `--respawn`), after a delay that grows while it keeps failing.
/// `SIGINT` and `SIGTERM` close every instance, letting its requests in
/// progress finish and running its shutdown hooks, before the process ends.
class Runner {
  final String name;
  final AngelConfigurer configureServer;
  final Reflector reflector;

  /// The default headers to remove, with the values to remove, as
  /// [AngelHttp.removeResponseHeader] takes them: a `null` value removes a
  /// header whatever its values.
  final Map<String, Object?> removeResponseHeaders;
  final Map<String, Object> responseHeaders;

  /// How long the instances may take to close on a shutdown signal, before
  /// they are killed: up to half of it lets their requests in progress
  /// finish (see [Driver.closeTimeout]), and the rest is for their shutdown
  /// hooks.
  final Duration shutdownTimeout;

  Runner(
    this.name,
    this.configureServer, {
    this.reflector = const EmptyReflector(),
    this.removeResponseHeaders = const {},
    this.responseHeaders = const {},
    this.shutdownTimeout = const Duration(seconds: 10),
  });

  static const String _asciiArt = '''

     _    _   _  ____ _____ _     _____
    / \\  | \\ | |/ ___| ____| |   |___ /
   / _ \\ |  \\| | |  _|  _| | |     |_ \\
  / ___ \\| |\\  | |_| | |___| |___ ___) |
 /_/   \\_\\_| \\_|\\____|_____|_____|____/
''';

  static final DateFormat _defaultDateFormat = DateFormat(
    'yyyy-MM-dd HH:mm:ss',
  );

  /// Whether the error of a record is not printed: that of an
  /// [AngelHttpException] that is not a 500, i.e. of a request.
  static bool _hidesError(Object? error) =>
      error is AngelHttpException && error.statusCode != 500;

  /// Prints [record], unless [RunnerOptions.quiet]. A record of an
  /// [AngelHttpException] that is not a 500 is printed without its error.
  static void handleLogRecord(LogRecord? record, RunnerOptions options) {
    if (options.quiet || record == null) return;
    var code = chooseLogColor(record.level);
    var now = _defaultDateFormat.format(record.time);
    var prefix = '$now ${record.level.name} [${record.loggerName}]';

    print(code.wrap('$prefix: ${record.message}'));

    var err = record.error;
    if (err == null || _hidesError(err)) {
      return;
    }
    print(code.wrap('$prefix: $err'));
    if (record.stackTrace != null) {
      print(code.wrap('$prefix: ${record.stackTrace}'));
    }
  }

  /// Chooses a color based on the logger [level].
  static AnsiCode chooseLogColor(Level level) {
    if (level == Level.SHOUT) {
      return backgroundRed;
    } else if (level == Level.SEVERE) {
      return red;
    } else if (level == Level.WARNING) {
      return yellow;
    } else if (level == Level.INFO) {
      return cyan;
    } else if (level == Level.FINER || level == Level.FINEST) {
      return lightGray;
    }
    return resetAll;
  }

  /// Spawns a new instance of the application in a separate isolate.
  ///
  /// If the command-line arguments permit, then the instance will be respawned on crashes.
  ///
  /// The returned [Future] completes when the application instance exits,
  /// or with a [StartupException] if it failed to start. If respawning is
  /// enabled, it completes only once the instance is stopped.
  ///
  /// Like those of [run], it is closed by [stop]; a [stop] before it does
  /// not apply to it.
  Future spawnIsolate(int id, RunnerOptions options, SendPort pubSubSendPort) {
    // Started after the stop, which applied to what ran then.
    _pendingStop = false;
    var instance = _track(_Instance(this, id, options, pubSubSendPort))
      ..spawn();
    return instance.done.future;
  }

  /// The instances that [run] and [spawnIsolate] run, until they are done.
  final List<_Instance> _instances = [];

  /// Whether [stop] came while no instance ran, which makes the next [run]
  /// return without starting instances.
  bool _pendingStop = false;

  /// Adds [instance] to [_instances] until it is done.
  _Instance _track(_Instance instance) {
    _instances.add(instance);
    instance.done.future
        .then((_) {}, onError: (_) {})
        .whenComplete(() => _instances.remove(instance));
    return instance;
  }

  /// Closes every instance of [run] and [spawnIsolate], letting its requests
  /// in progress finish and running its shutdown hooks (or kills it after
  /// [shutdownTimeout]), so that [run] returns; as `SIGINT` and `SIGTERM` do.
  ///
  /// Called while no instance runs, it makes the next [run] return without
  /// starting instances, unless [spawnIsolate] starts one before. A [run]
  /// starts its instances as soon as it is called, so it cannot be stopped
  /// in between.
  void stop() {
    if (_instances.isEmpty) {
      // Nothing to close: only the next run returns without starting.
      _pendingStop = true;
      return;
    }
    for (var instance in _instances.toList()) {
      instance.stop(shutdownTimeout);
    }
  }

  /// Starts a number of isolates, running identical instances of an Angel application.
  Future run(List<String> args) async {
    Server? server;
    var instances = <_Instance>[];
    var signals = <StreamSubscription>[];

    try {
      var argResults = RunnerOptions.argParser.parse(args);

      if (argResults['help'] == true) {
        print(darkGray.wrap(_banner));
        stdout
          ..writeln('Options:')
          ..writeln(RunnerOptions.argParser.usage);
        return;
      }

      var options = RunnerOptions.fromArgResults(argResults);
      options.responseHeaders.addAll(responseHeaders);
      options.removeResponseHeaders.addAll(removeResponseHeaders);

      if (options.ssl || options.http2) {
        if (options.certificateFile == null) {
          throw ArgParserException('Missing --certificate-file option.');
        } else if (options.keyFile == null) {
          throw ArgParserException('Missing --key-file option.');
        }
      }

      print(darkGray.wrap(_banner));
      print('Starting `$name` application...');

      if (_pendingStop) {
        _pendingStop = false;
        return;
      }

      var adapter = IsolateAdapter();
      server = Server([adapter]);
      for (var i = 0; i < options.concurrency; i++) {
        server.registerClient(ClientInfo('client$i'));
      }
      server.start();

      for (var id = 0; id < options.concurrency; id++) {
        instances.add(
          _track(_Instance(this, id, options, adapter.receivePort.sendPort))
            ..spawn(),
        );
      }

      // Closes every instance on a signal; a second one ends at once. Each
      // run has its own handler, so it counts the signals it got itself.
      var signalled = false;
      void onSignal(ProcessSignal signal) {
        if (signalled) exit(ExitCode.software.code);
        signalled = true;
        print('Received $signal. Shutting down...');
        stop();
      }

      for (var signal in [
        ProcessSignal.sigint,
        // Windows has no SIGTERM.
        if (!Platform.isWindows) ProcessSignal.sigterm,
      ]) {
        signals.add(
          signal.watch().listen(
            onSignal,
            // Not to be watched on this platform.
            onError: (Object e) {},
          ),
        );
      }

      await Future.wait([
        for (var instance in instances) instance.done.future,
      ], eagerError: true);
    } on ArgParserException catch (e) {
      stderr
        ..writeln(red.wrap(e.message))
        ..writeln()
        ..writeln(red.wrap('Options:'))
        ..writeln(red.wrap(RunnerOptions.argParser.usage));
      exitCode = ExitCode.usage.code;
    } on StartupException catch (e) {
      stderr.writeln(red.wrap('$e'));
      exitCode = ExitCode.software.code;
      await _stopAll(instances);
    } catch (e, st) {
      stderr
        ..writeln(red.wrap('fatal error: $e'))
        ..writeln(red.wrap(st.toString()));
      exitCode = 1;
      await _stopAll(instances);
    } finally {
      for (var sub in signals) {
        await sub.cancel();
      }
      await server?.close();
    }
  }

  /// Stops [instances], those of one [run], and waits until each has exited.
  Future<void> _stopAll(List<_Instance> instances) {
    for (var instance in instances) {
      instance.stop(shutdownTimeout);
    }
    return Future.wait([
      for (var instance in instances)
        instance.done.future.then((_) {}, onError: (_) {}),
    ]);
  }

  static const String _banner =
      '$_asciiArt\n\nA batteries-included, full-featured, full-stack framework in Dart.\n\nhttps://angel3-framework.web.app\n';

  /// Run with main isolate
  static void isolateMain(RunnerArgsWithId argsWithId) {
    var args = argsWithId.args;
    var toMain = args.loggingSendPort;
    hierarchicalLoggingEnabled = false;

    var zone = Zone.current.fork(
      specification: ZoneSpecification(
        print: (self, parent, zone, msg) {
          toMain.send(_Log(Level.INFO, msg, args.loggerName));
        },
      ),
    );

    zone.run(() async {
      var control = ReceivePort();
      Driver driver;
      try {
        driver = await _startInstance(argsWithId);
      } catch (e, st) {
        // The main isolate ends the runner, rather than respawn the same
        // failure.
        toMain.send(_StartFailed('$e', '$st'));
        control.close();
        Isolate.exit();
      }

      control.listen((message) async {
        if (message != _stop) return;
        try {
          await driver.close();
        } catch (e, st) {
          toMain.send(
            _Log(Level.SEVERE, 'Failed to close', args.loggerName, '$e', '$st'),
          );
        }
        // The driver waited for its connections to close, but a TLS socket
        // still writes its last bytes after that, which exiting the isolate
        // would cut off.
        await Future.delayed(_exitGrace);
        control.close();
        Isolate.exit();
      });
      toMain.send(_Started(control.sendPort));
    });
  }

  /// Makes and starts the server of an instance, logging to the main
  /// isolate.
  static Future<Driver> _startInstance(RunnerArgsWithId argsWithId) async {
    var args = argsWithId.args;
    var options = args.options;
    var client = IsolateClient('client${argsWithId.id}', args.pubSubSendPort);

    var app = Angel(reflector: args.reflector)
      ..container.registerSingleton<Client>(client)
      ..container.registerSingleton(InstanceInfo(id: argsWithId.id));

    // Before configureServer, which may log, or set a logger of its own.
    // With hierarchical logging off, this gets the records of every logger,
    // which it prints: a listener of configureServer that prints them too
    // prints each record twice.
    app.logger = Logger(args.loggerName)
      ..onRecord.listen((rec) => args.loggingSendPort.send(_Log.of(rec)));

    app.shutdownHooks.add((_) => client.close());

    await app.configure(args.configureServer);

    SecurityContext? securityContext;
    if (options.ssl || options.http2) {
      securityContext = SecurityContext()
        ..useCertificateChain(
          options.certificateFile!,
          password: options.certificatePassword,
        )
        ..usePrivateKey(options.keyFile!, password: options.keyPassword);
    }

    Driver driver;
    if (options.http2) {
      securityContext!.setAlpnProtocols(['h2'], true);
      // Its own HTTP/1 fallback, which it drains with its HTTP/2 requests
      // when it is closed.
      var http2 = AngelHttp2.custom(
        app,
        securityContext,
        startSharedHttp2,
        useZone: options.useZone,
        allowHttp1: true,
      );
      driver = http2;
    } else if (options.ssl) {
      driver = AngelHttp.custom(
        app,
        startSharedSecure(securityContext!),
        useZone: options.useZone,
      );
    } else {
      driver = AngelHttp.custom(app, startShared, useZone: options.useZone);
    }

    driver.closeTimeout = args.closeTimeout;
    await driver.startServer(options.hostname, options.port);

    // As defaults of the server, which a handler's headers replace.
    if (driver is AngelHttp) {
      driver.addResponseHeader(options.responseHeaders);
      driver.removeResponseHeader(options.removeResponseHeaders);
    } else if (driver is AngelHttp2) {
      // Its HTTP/2 responses, and those of the HTTP/1 requests it serves.
      driver.addResponseHeader(options.responseHeaders);
      driver.removeResponseHeader(options.removeResponseHeaders);
    }

    var serverUrl = driver.uri;
    if (options.ssl || options.http2) {
      serverUrl = serverUrl.replace(scheme: 'https');
    }
    print('Instance #${argsWithId.id} listening at $serverUrl');
    return driver;
  }
}

/// An instance that failed to start, which ends [Runner.run].
class StartupException implements Exception {
  final int id;
  final String error, stackTrace;

  const StartupException(this.id, this.error, this.stackTrace);

  @override
  String toString() => 'Instance #$id failed to start: $error\n$stackTrace';
}

/// The message to an instance's control port that stops it.
const String _stop = 'stop';

/// How long a closed instance waits before its isolate exits.
const Duration _exitGrace = Duration(milliseconds: 100);

/// A log record of an instance, sent to the main isolate to be printed.
class _Log {
  final Level level;
  final String message, loggerName;
  final String? error, stackTrace;
  final DateTime time;

  _Log(this.level, this.message, this.loggerName, [this.error, this.stackTrace])
    : time = DateTime.now();

  _Log.of(LogRecord record)
    : level = record.level,
      message = record.message,
      loggerName = record.loggerName,
      // As text, which every error can be sent as.
      error = Runner._hidesError(record.error)
          ? null
          : record.error?.toString(),
      stackTrace = record.stackTrace?.toString(),
      time = record.time;

  LogRecord toRecord() => _SentLogRecord(
    level,
    message,
    loggerName,
    error,
    stackTrace == null ? null : StackTrace.fromString(stackTrace!),
    time,
  );
}

/// A record of an instance, with the time it was logged at, not the time
/// the main isolate received it.
class _SentLogRecord extends LogRecord {
  final DateTime _time;

  _SentLogRecord(
    super.level,
    super.message,
    super.loggerName,
    super.error,
    super.stackTrace,
    this._time,
  );

  @override
  DateTime get time => _time;
}

/// An instance that started, with the port that stops it.
class _Started {
  final SendPort control;
  _Started(this.control);
}

/// An instance that failed to start.
class _StartFailed {
  final String error, stackTrace;
  _StartFailed(this.error, this.stackTrace);
}

/// An instance of the application, which runs in an isolate, respawned on
/// crashes with a delay that grows while it keeps crashing.
class _Instance {
  final Runner runner;
  final int id;
  final RunnerOptions options;
  final SendPort pubSubSendPort;
  final Completer<void> done = Completer<void>();

  SendPort? _control;
  Isolate? _isolate;
  bool _stopping = false;

  /// Whether an isolate is being spawned, or runs: its exit is still to
  /// come.
  bool _running = false;

  /// Whether the instance has started once, after which a failure to start
  /// again is respawned, like a crash.
  bool _hasStarted = false;
  DateTime? _startedAt;
  Duration _backoff = Duration.zero;
  Timer? _respawnTimer;

  static const _maxBackoff = Duration(seconds: 30);

  /// How long an instance must run for its next crash to be respawned at
  /// once again.
  static const _stableUptime = Duration(minutes: 1);

  _Instance(this.runner, this.id, this.options, this.pubSubSendPort);

  String get _loggerName => runner.name;

  void _log(Level level, String message, [Object? error, StackTrace? st]) =>
      Runner.handleLogRecord(
        LogRecord(level, message, _loggerName, error, st),
        options,
      );

  void spawn() {
    if (_stopping) return;
    // Its exit too, so that it comes after the messages it sent before.
    var fromIsolate = ReceivePort();
    var onError = ReceivePort();
    _StartFailed? startFailure;
    _startedAt = null;
    _running = true;

    fromIsolate.listen((message) {
      if (message == null) {
        // Its exit.
        fromIsolate.close();
        onError.close();
        _control = null;
        _isolate = null;
        _running = false;
        _exited(startFailure);
      } else if (message is _Log) {
        Runner.handleLogRecord(message.toRecord(), options);
      } else if (message is _Started) {
        _control = message.control;
        _startedAt = DateTime.now();
        _hasStarted = true;
        if (_stopping) message.control.send(_stop);
      } else if (message is _StartFailed) {
        startFailure = message;
      }
    });

    onError.listen((msg) {
      if (msg is List && msg.length == 2) {
        _log(
          Level.SEVERE,
          'Uncaught error',
          msg[0],
          StackTrace.fromString('${msg[1]}'),
        );
      } else {
        _log(Level.SEVERE, 'Uncaught error', msg);
      }
    });

    Isolate.spawn(
      Runner.isolateMain,
      RunnerArgsWithId(
        id,
        RunnerArgs(
          runner.name,
          runner.configureServer,
          options,
          runner.reflector,
          fromIsolate.sendPort,
          pubSubSendPort,
          closeTimeout: runner.shutdownTimeout ~/ 2,
        ),
      ),
      onExit: fromIsolate.sendPort,
      onError: onError.sendPort,
      errorsAreFatal: false,
    ).then((isolate) => _isolate = isolate).catchError((
      Object e,
      StackTrace st,
    ) {
      fromIsolate.close();
      onError.close();
      _running = false;
      // As a failure of the instance to start: it ends the runner unless
      // the instance has started before, when it is respawned.
      _exited(_StartFailed('$e', '$st'));
      return Isolate.current;
    });
  }

  void _exited(_StartFailed? startFailure) {
    if (done.isCompleted) return;
    if (_stopping) {
      done.complete();
    } else if (startFailure != null && !_hasStarted) {
      done.completeError(
        StartupException(id, startFailure.error, startFailure.stackTrace),
      );
    } else if (!options.respawn) {
      done.complete();
    } else {
      var started = _startedAt;
      var uptime = started == null
          ? Duration.zero
          : DateTime.now().difference(started);
      _backoff = uptime >= _stableUptime
          ? Duration.zero
          : Duration(
              milliseconds: min(
                _maxBackoff.inMilliseconds,
                max(1000, _backoff.inMilliseconds * 2),
              ),
            );
      var when = _backoff == Duration.zero
          ? 'immediately'
          : 'in ${_backoff.inSeconds}s';
      if (startFailure != null) {
        _log(
          Level.SEVERE,
          'Instance #$id failed to start again. Respawning $when...',
          startFailure.error,
          StackTrace.fromString(startFailure.stackTrace),
        );
      } else {
        _log(Level.WARNING, 'Instance #$id crashed. Respawning $when...');
      }
      _respawnTimer = Timer(_backoff, spawn);
    }
  }

  /// Closes the instance, which runs its shutdown hooks, or kills it after
  /// [timeout].
  void stop(Duration timeout) {
    if (_stopping) return;
    _stopping = true;
    _respawnTimer?.cancel();
    var control = _control;
    if (control != null) {
      control.send(_stop);
    } else if (!_running) {
      // Waiting to be respawned.
      if (!done.isCompleted) done.complete();
      return;
    }
    // Otherwise still starting: it is stopped once it has started, unless
    // it exits first.
    var kill = Timer(timeout, () {
      if (done.isCompleted) return;
      _log(Level.WARNING, 'Instance #$id did not close in time; killed.');
      _isolate?.kill(priority: Isolate.immediate);
    });
    // A pending timer would keep the process alive after run() returns.
    done.future.then((_) => kill.cancel(), onError: (_) => kill.cancel());
  }
}

class RunnerArgsWithId {
  final int id;
  final RunnerArgs args;

  RunnerArgsWithId(this.id, this.args);
}

class RunnerArgs {
  final String name;

  final AngelConfigurer configureServer;

  final RunnerOptions options;

  final Reflector reflector;

  /// The port of the messages of an instance to the main isolate: its log
  /// records, and whether it started.
  final SendPort loggingSendPort, pubSubSendPort;

  /// How long the instance waits for its requests in progress when it is
  /// stopped (see [Driver.closeTimeout]).
  final Duration closeTimeout;

  RunnerArgs(
    this.name,
    this.configureServer,
    this.options,
    this.reflector,
    this.loggingSendPort,
    this.pubSubSendPort, {
    this.closeTimeout = const Duration(seconds: 5),
  });

  String get loggerName => name;
}
