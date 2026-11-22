# Issue 105

how to integrate Prometheus and Grafana with Angel Framework

I have several backend projects with Angel and I would like to monitor requests per second, memory and CPU usage, average response time, total users per day, total simultaneous users, total failures, among other possible metrics

I noticed that there is a package for the "shelf" that allows integration with Prometheus to capture the metrics, I saw that in the "shelf" the middleware is a "FutureOr Function(Request) Function(FutureOr Function(Request) ) middleware" this allows, for example, the middleware to calculate the time of a request
like this
middleware

```dart
/// Register default metrics for the shelf and returns a [shelf.Middleware] that
/// can be added to the [shelf.Pipeline]. If no [registry] is provided, the
/// [CollectorRegistry.defaultRegistry] is used.
shelf.Middleware register([CollectorRegistry? registry]) {
  final histogram = Histogram(
    name: 'http_request_duration_seconds',
    help: 'A histogram of the HTTP request durations.',
    labelNames: ['method', 'code'],
  );

  registry ??= CollectorRegistry.defaultRegistry;
  registry.register(histogram);

  return (innerHandler) {
    return (request) {
      var watch = Stopwatch()..start();

      return Future.sync(() => innerHandler(request)).then((response) {
        histogram.labels([request.method, '${response.statusCode}']).observe(
            watch.elapsedMicroseconds / Duration.microsecondsPerSecond);

        return response;
      }, onError: (error, StackTrace stackTrace) {
        if (error is shelf.HijackException) {
          throw error;
        }

        histogram.labels([request.method, '000']).observe(
            watch.elapsedMicroseconds / Duration.microsecondsPerSecond);

        throw error;
      });
    };
  };
}
```

API example with prometheus

```dart

import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

import 'package:prometheus_client/prometheus_client.dart';
import 'package:prometheus_client/runtime_metrics.dart' as runtime_metrics;
import 'package:prometheus_client_shelf/shelf_metrics.dart' as shelf_metrics;
import 'package:prometheus_client_shelf/shelf_handler.dart';

//https://github.com/rocketseat-creators-program/dart-shelf-auth-api-2022-05-07
void main(List<String> arguments) async {
  // Register default runtime metrics
  runtime_metrics.register();

  // Create a metric of type counter.
  // Always register your metric, either at the default registry or a custom one.
  final greetingCounter = Counter(
    name: 'greetings_total',
    help: 'The total amount of greetings',
  )..register();

  final app = Router();

  app.get('/hello', (Request request) {
    // Every time the hello is called, increase the counter by one
    greetingCounter.inc();
    return Response.ok('hello-world');
  });

  // Register a handler to expose the metrics in the Prometheus text format
  app.get('/metrics', prometheusHandler());

  final authRepository = AuthRepository();

  app.get('/me', (Request request) async {
    final key = request.headers['Authorization'];

    final user = authRepository.getUser(key!);

    if (user != null) {
      return Response.ok(
        user.toJson(),
        headers: {
          'Content-Type': 'application/json',
        },
      );
    }

    return Response.forbidden('');
  });

  app.post('/register', (Request request) async {
    final params = jsonDecode(await request.readAsString());

    final token = authRepository.register(
      params['name'],
      params['email'],
      params['password'],
    );

    if (token != null) {
      return Response.ok(token);
    } else {
      return Response.forbidden('');
    }
  });

  app.post('/login', (Request request) async {
    final params = jsonDecode(await request.readAsString());

    final token = authRepository.login(
      params['email'],
      params['password'],
    );

    if (token != null) {
      return Response.ok(token);
    }

    return Response.forbidden('Email and/or password incorrect');
  });

  final authMid = createMiddleware(requestHandler: (Request req) {
    if (req.url.toString() == 'me' && req.headers['Authorization'] == null) {
      return Response.forbidden('');
    }
  });

  final handler = Pipeline()
      // Register a middleware to track request times
      .addMiddleware(shelf_metrics.register())
      .addMiddleware((innerHandler) {
        final http_requests_total = Counter(
          name: 'http_requests_total',
          help: 'Total number of http api requests'
        )..register();

        return (request) async {
          // Every time http_request is called, increase the counter by one
          final resp = await innerHandler(request);
          http_requests_total.inc();        
          return resp;
        };
      })
      .addMiddleware(logRequests())
      .addMiddleware(authMid)
      .addHandler(app);
  final server = await io.serve(handler, '192.168.66.123', 8080);

  print('Serving at http://${server.address.host}:${server.port}');
}

class AuthRepository {
  final users = <String, User>{};

  String _generateKey(String seed) => base64Encode(utf8.encode(seed));

  String? register(String name, String email, String password) {
    final newUser = User(name: name, email: email, password: password);

    final key = _generateKey(newUser.toString());

    if (users.containsKey(key)) {
      return null;
    }

    users[key] = newUser;

    return key;
  }

  String? login(String email, String password) {
    final key = _generateKey(email);

    final user = users[key];

    if (user != null && user.password == password) {
      return key;
    }

    return null;
  }

  User? getUser(String key) {
    final user = users[key];

    if (user != null) {
      return user;
    }

    return null;
  }
}

class User {
  final String name;
  final String email;
  final String password;

  User({
    required this.name,
    required this.email,
    required this.password,
  });

  @override
  String toString() => email;

  toJson() => jsonEncode(
        {
          'email': email,
          'name': name,
        },
      );
}
```

I took runner.dart from the angel3_production package and modified it to use the stream_isolate package and prometheus_client to add metrics capture to prometheus, I don't know if this is the best way, if you have any ideas to help me I'll be very grateful and Who knows, I might make a pull request or release a package that allows this integration

```dart
import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:intl/intl.dart';
import 'package:angel3_container/angel3_container.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_framework/http2.dart';
import 'package:args/args.dart';
import 'package:io/ansi.dart';
import 'package:io/io.dart';
import 'package:logging/logging.dart';
import 'package:belatuk_pub_sub/isolate.dart' as pub_sub;
import 'package:belatuk_pub_sub/belatuk_pub_sub.dart' as pub_sub;

import 'package:new_sali_backend/src/shared/dependencies/stream_isolate/stream_isolate.dart';
import 'package:prometheus_client/prometheus_client.dart';
import 'package:prometheus_client/format.dart' as format;
import 'package:prometheus_client/runtime_metrics.dart' as runtime_metrics;

import 'instance_info.dart';
import 'options.dart';

/// A command-line utility for easier running of multiple instances of an Angel application.
///
/// Makes it easy to do things like configure SSL, log messages, and send messages between
/// all running instances.
class Runner {
  final String name;
  final AngelConfigurer configureServer;
  final Reflector reflector;

  Runner(this.name, this.configureServer,
      {this.reflector = const EmptyReflector()});

  static const String asciiArt2 = '''

    ___    _   ________________   _____
   /   |  / | / / ____/ ____/ /  |__  /
  / /| | /  |/ / / __/ __/ / /    /_ < 
 / ___ |/ /|  / /_/ / /___/ /______/ / 
/_/  |_/_/ |_/\\____/_____/_____/____/ 
                                                                                                                       
''';

  static const String asciiArt = '''

     _    _   _  ____ _____ _     _____ 
    / \\  | \\ | |/ ___| ____| |   |___ / 
   / _ \\ |  \\| | |  _|  _| | |     |_ \\ 
  / ___ \\| |\\  | |_| | |___| |___ ___) |
 /_/   \\_\\_| \\_|\\____|_____|_____|____/                                                                                 
''';

  static const String asciiArtOld = '''
____________   ________________________ 
___    |__  | / /_  ____/__  ____/__  / 
__  /| |_   |/ /_  / __ __  __/  __  /  
_  ___ |  /|  / / /_/ / _  /___  _  /___
/_/  |_/_/ |_/  ____/  /_____/  /_____/
                                        
''';

  static final DateFormat _defaultDateFormat =
      DateFormat('yyyy-MM-dd HH:mm:ss');

  /// LogRecord handler
  static void handleLogRecord(LogRecord? record, RunnerOptions options) {
    if (options.quiet || record == null) return;
    var code = chooseLogColor(record.level);

    var now = _defaultDateFormat.format(DateTime.now());

    if (record.error == null) {
      //print(code.wrap(record.message));
      print(code.wrap(
          '$now ${record.level.name} [${record.loggerName}]: ${record.message}'));
    }

    if (record.error != null) {
      var err = record.error;
      if (err is AngelHttpException && err.statusCode != 500) return;
      //print(code.wrap(record.message + '\n'));
      print(code.wrap(
          '$now ${record.level.name} [${record.loggerName}]: ${record.message} \n'));
      print(code.wrap(
          '$now ${record.level.name} [${record.loggerName}]: ${err.toString()}'));

      if (record.stackTrace != null) {
        print(code.wrap(
            '$now ${record.level.name} [${record.loggerName}]: ${record.stackTrace.toString()}'));
      }
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
  /// The returned [Future] completes when the application instance exits.
  ///
  /// If respawning is enabled, the [Future] will *never* complete.
  Future spawnIsolate(int id, RunnerOptions options, SendPort pubSubSendPort) {
    return _spawnIsolate(id, Completer(), options, pubSubSendPort);
  }

  final streamIsolates = <Map<int, BidirectionalStreamIsolate>>[];

  /// receive msg from one isolate and send to all isolates
  void receiveAndPass(event, int idx) {
    streamIsolates.forEach((item) {
      item.values.first.send(event);
    });
  }

  Future _spawnIsolate(
      int id, Completer c, RunnerOptions options, SendPort pubSubSendPort) {
    var onLogRecord = ReceivePort();
    var onExit = ReceivePort();
    var onError = ReceivePort();
    var runnerArgs = RunnerArgs(name, configureServer, options, reflector,
        onLogRecord.sendPort, pubSubSendPort);
    var argsWithId = RunnerArgsWithId(id, runnerArgs);

    // Isolate.spawn(isolateMain, argsWithId,
    //         onExit: onExit.sendPort,
    //         onError: onError.sendPort,
    //         errorsAreFatal: true && false)

    StreamIsolate.spawnBidirectional(isolateMainStream,
            argument: argsWithId,
            onExit: onExit.sendPort,
            onError: onError.sendPort,
            errorsAreFatal: true && false)
        .then((streamIsolate) {
      streamIsolates.add({id: streamIsolate});
      streamIsolate.stream.listen((event) => receiveAndPass(event, id));
    })
        //.catchError(c.completeError);
        .catchError((e) {
      c.completeError(e as Object);
      return null;
    });

    onLogRecord.listen((msg) => handleLogRecord(msg as LogRecord?, options));

    onError.listen((msg) {
      if (msg is List) {
        dynamic e = msg[0];
        var st = StackTrace.fromString(msg[1].toString());
        handleLogRecord(
            LogRecord(
                Level.SEVERE, 'Fatal error', runnerArgs.loggerName, e, st),
            options);
      } else {
        handleLogRecord(
            LogRecord(Level.SEVERE, 'Fatal error', runnerArgs.loggerName, msg),
            options);
      }
    });

    onExit.listen((_) {
      if (options.respawn) {
        handleLogRecord(
            LogRecord(
                Level.WARNING,
                'Instance #$id at ${DateTime.now()} crashed. Respawning immediately...',
                runnerArgs.loggerName),
            options);
        _spawnIsolate(id, c, options, pubSubSendPort);
      } else {
        c.complete();
      }
    });

    return c.future
        .whenComplete(onExit.close)
        .whenComplete(onError.close)
        .whenComplete(onLogRecord.close);
  }

  //  isaque adicionou
  /// Boots a shared server instance. Use this if launching multiple isolates.
  static Future<HttpServer> Function(dynamic, int) startSharedHttpServer() {
    return (address, int port) async {
      final server =
          await HttpServer.bind(address ?? '127.0.0.1', port, shared: true);
      server.defaultResponseHeaders.remove('X-Frame-Options', 'SAMEORIGIN');
      return Future.value(server);
    };
  }

  static Future<HttpServer> Function(dynamic, int) startSharedSecureHttpServer(
      SecurityContext securityContext) {
    return (address, int port) async {
      final server = await HttpServer.bindSecure(
          address ?? '127.0.0.1', port, securityContext,
          shared: true);
      server.defaultResponseHeaders.remove('X-Frame-Options', 'SAMEORIGIN');
      return Future.value(server);
    };
  }
  //  isaque adicionou para comunicação entre os isolados
  // final streamIsolates = <Map<int, BidirectionalStreamIsolate>>[];

  /// Starts a number of isolates, running identical instances of an Angel application.
  Future run(List<String> args) async {
    pub_sub.Server? server;

    try {
      var argResults = RunnerOptions.argParser.parse(args);
      var options = RunnerOptions.fromArgResults(argResults);

      if (options.ssl || options.http2) {
        if (options.certificateFile == null) {
          throw ArgParserException('Missing --certificate-file option.');
        } else if (options.keyFile == null) {
          throw ArgParserException('Missing --key-file option.');
        }
      }

      print(darkGray.wrap(
          '$asciiArt\n\nA batteries-included, full-featured, full-stack framework in Dart.\n\nhttps://angel3-framework.web.app\n'));

      if (argResults['help'] == true) {
        stdout
          ..writeln('Options:')
          ..writeln(RunnerOptions.argParser.usage);
        return;
      }

      print('Starting `$name` application...');

      var adapter = pub_sub.IsolateAdapter();
      server = pub_sub.Server([adapter]);

      // Register clients
      for (var i = 0; i < Platform.numberOfProcessors; i++) {
        server.registerClient(pub_sub.ClientInfo('client$i'));
      }

      server.start();

      await Future.wait(List.generate(options.concurrency,
          (id) => spawnIsolate(id, options, adapter.receivePort.sendPort)));
    } on ArgParserException catch (e) {
      stderr
        ..writeln(red.wrap(e.message))
        ..writeln()
        ..writeln(red.wrap('Options:'))
        ..writeln(red.wrap(RunnerOptions.argParser.usage));
      exitCode = ExitCode.usage.code;
    } catch (e, st) {
      stderr
        ..writeln(red.wrap('fatal error: $e'))
        ..writeln(red.wrap(st.toString()));
      exitCode = 1;
    } finally {
      await server?.close();
    }
  }

  /// isaque add this to capture metrics
  static Stream isolateMainStream(Stream inc, dynamic argsWithId) {
    final isolateToMainStream = StreamController.broadcast();

    final reg = CollectorRegistry(); //CollectorRegistry.defaultRegistry;
    // Register default runtime metrics
    runtime_metrics.register(reg);
    // Register http requests total metrics
    final http_requests_total = Counter(
        name: 'http_requests_total', help: 'Total number of http api requests');
    http_requests_total.register(reg);
    // listen msg from main
    inc.listen((msg) {
      http_requests_total.inc();
    });

    final args = argsWithId as RunnerArgsWithId;
    isolateMain(args, isolateToMainStream, reg);
    return isolateToMainStream.stream;
  }

// isaque add middleware to regiter API access fro prometheus
  static void configurePrometheus(
      Angel app, StreamController isolateToMainStream, CollectorRegistry reg) {
    app.all('*', (RequestContext req, ResponseContext resp) async {
      // Every time http_request is called, increase the counter by one
      if (!req.path.contains('metrics')) {
        //send msg to main
        isolateToMainStream.add('+1');
      }
      return true;
    });
    // Register a handler to expose the metrics in the Prometheus text format
    app.get('/metrics', (RequestContext req, ResponseContext resp) async {
      final buffer = StringBuffer();
      final metrics = await reg.collectMetricFamilySamples();
      format.write004(buffer, metrics);
      resp.write(buffer.toString());
      resp.headers.addAll({'Content-Type': format.contentType});
    });
  }

  /// Run with main isolate
  static void isolateMain(
      RunnerArgsWithId argsWithId,
      StreamController isolateToMainStream,
      CollectorRegistry collectorRegistry) {
    var args = argsWithId.args;
    hierarchicalLoggingEnabled = false;

    var zone = Zone.current.fork(specification: ZoneSpecification(
      print: (self, parent, zone, msg) {
        args.loggingSendPort.send(LogRecord(Level.INFO, msg, args.loggerName));
      },
    ));

    zone.run(() async {
      var client =
          pub_sub.IsolateClient('client${argsWithId.id}', args.pubSubSendPort);

      var app = Angel(reflector: args.reflector)
        ..container.registerSingleton<pub_sub.Client>(client)
        ..container.registerSingleton(InstanceInfo(id: argsWithId.id));

      app.shutdownHooks.add((_) => client.close());

      // isaque add middleware to regiter API access fro prometheus
      configurePrometheus(app, isolateToMainStream, collectorRegistry);

      await app.configure(args.configureServer);

      app.logger = Logger(args.loggerName)
        ..onRecord.listen((rec) => Runner.handleLogRecord(rec, args.options));

      AngelHttp http;
      late SecurityContext securityContext;
      Uri serverUrl;

      if (args.options.ssl || args.options.http2) {
        securityContext = SecurityContext();
        if (args.options.certificateFile != null) {
          securityContext.useCertificateChain(args.options.certificateFile!,
              password: args.options.certificatePassword);
        }

        if (args.options.keyFile != null) {
          securityContext.usePrivateKey(args.options.keyFile!,
              password: args.options.keyPassword);
        }
      }

      if (args.options.ssl) {
        //  change to startSharedSecureHttpServer
        http = AngelHttp.custom(
            app, startSharedSecureHttpServer(securityContext),
            useZone: args.options.useZone);
      } else {
        //  change to startSharedHttpServer
        http = AngelHttp.custom(app, startSharedHttpServer(),
            useZone: args.options.useZone);
      }

      Driver driver;

      if (args.options.http2) {
        securityContext.setAlpnProtocols(['h2'], true);
        var http2 = AngelHttp2.custom(app, securityContext, startSharedHttp2,
            useZone: args.options.useZone);
        http2.onHttp1.listen(http.handleRequest);
        driver = http2;
      } else {
        driver = http;
      }

      await driver.startServer(args.options.hostname, args.options.port);
      serverUrl = driver.uri;
      if (args.options.ssl || args.options.http2) {
        serverUrl = serverUrl.replace(scheme: 'https');
      }
      print('Instance #${argsWithId.id} listening at $serverUrl');
    });
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

  final SendPort loggingSendPort, pubSubSendPort;

  RunnerArgs(this.name, this.configureServer, this.options, this.reflector,
      this.loggingSendPort, this.pubSubSendPort);

  String get loggerName => name;
}
```
