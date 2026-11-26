/// A small HTTP/1.1 load generator, used in place of `wrk`.
///
/// Each isolate keeps its share of the connections open (keep-alive), and
/// each connection sends one request, reads the whole response, and sends
/// the next, until the duration is over. A `*` in the path is replaced by a
/// number that differs for every request, so a route with a parameter is
/// requested with a new value each time.
///
/// ```sh
/// dart run bin/load.dart -c 64 -d 10 -i 2 'GET /user/*'
/// ```
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

Future<void> main(List<String> args) async {
  var options = _Options.parse(args);
  var results = ReceivePort();
  for (var i = 0; i < options.isolates; i++) {
    await Isolate.spawn(_runIsolate, (options, i, results.sendPort));
  }

  var stats = <_Stats>[];
  await for (var message in results) {
    stats.add(_Stats.fromMessage(message as List));
    if (stats.length == options.isolates) break;
  }
  results.close();

  var total = _Stats.merge(stats);
  print(total.report(options));
}

class _Options {
  final String host;
  final int port;
  final int connections;
  final Duration duration;
  final int isolates;
  final String method;
  final String path;

  _Options(
    this.host,
    this.port,
    this.connections,
    this.duration,
    this.isolates,
    this.method,
    this.path,
  );

  static _Options parse(List<String> args) {
    var host = '127.0.0.1';
    var port = 3000;
    var connections = 64;
    var seconds = 10;
    var isolates = 2;
    String? target;
    for (var i = 0; i < args.length; i++) {
      switch (args[i]) {
        case '-h':
          host = args[++i];
        case '-p':
          port = int.parse(args[++i]);
        case '-c':
          connections = int.parse(args[++i]);
        case '-d':
          seconds = int.parse(args[++i]);
        case '-i':
          isolates = int.parse(args[++i]);
        default:
          target = args[i];
      }
    }
    var parts = (target ?? 'GET /').split(' ');
    return _Options(
      host,
      port,
      connections,
      Duration(seconds: seconds),
      isolates,
      parts[0],
      parts[1],
    );
  }

  /// The connections run by isolate [index].
  int connectionsOf(int index) =>
      connections ~/ isolates + (index < connections % isolates ? 1 : 0);
}

class _Stats {
  int requests = 0;
  int errors = 0;
  int non2xx = 0;
  final List<int> latencies;

  _Stats([List<int>? latencies]) : latencies = latencies ?? <int>[];

  List<Object> toMessage() => [
    requests,
    errors,
    non2xx,
    Int32List.fromList(latencies),
  ];

  static _Stats fromMessage(List message) =>
      _Stats((message[3] as Int32List).toList())
        ..requests = message[0] as int
        ..errors = message[1] as int
        ..non2xx = message[2] as int;

  static _Stats merge(List<_Stats> all) {
    var out = _Stats();
    for (var s in all) {
      out
        ..requests += s.requests
        ..errors += s.errors
        ..non2xx += s.non2xx
        ..latencies.addAll(s.latencies);
    }
    return out;
  }

  String report(_Options o) {
    latencies.sort();
    String ms(int us) => (us / 1000).toStringAsFixed(2);
    int at(double q) =>
        latencies.isEmpty ? 0 : latencies[((latencies.length - 1) * q).round()];
    var avg = latencies.isEmpty
        ? 0
        : latencies.reduce((a, b) => a + b) ~/ latencies.length;
    var rps = requests / (o.duration.inMicroseconds / 1e6);
    return [
      '${o.method} ${o.path}',
      'req/s=${rps.toStringAsFixed(0)}',
      'avg=${ms(avg)}ms',
      'p50=${ms(at(.5))}ms',
      'p99=${ms(at(.99))}ms',
      'requests=$requests',
      'errors=$errors',
      'non2xx=$non2xx',
    ].join('  ');
  }
}

Future<void> _runIsolate((_Options, int, SendPort) args) async {
  var (options, index, results) = args;
  var stats = _Stats();
  var clock = Stopwatch()..start();
  var end = options.duration.inMicroseconds;
  // Distinct per isolate, so that no two requests share a value.
  var counter = index * 100000000;
  var varying = options.path.contains('*');
  var hostHeader = '${options.host}:${options.port}';

  Uint8List request(int n) {
    var path = varying ? options.path.replaceFirst('*', '$n') : options.path;
    var body = options.method == 'POST' ? 'content-length: 0\r\n' : '';
    return latin1.encode(
      '${options.method} $path HTTP/1.1\r\nhost: $hostHeader\r\n$body\r\n',
    );
  }

  var fixed = varying ? null : request(0);

  Future<void> connection() async {
    while (clock.elapsedMicroseconds < end) {
      Socket socket;
      try {
        socket = await Socket.connect(options.host, options.port);
      } catch (_) {
        stats.errors++;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        continue;
      }
      socket.setOption(SocketOption.tcpNoDelay, true);
      var reader = _ResponseReader(socket);
      try {
        while (clock.elapsedMicroseconds < end) {
          var started = clock.elapsedMicroseconds;
          socket.add(fixed ?? request(counter++));
          var status = await reader.next();
          stats.latencies.add(clock.elapsedMicroseconds - started);
          stats.requests++;
          if (status < 200 || status > 299) stats.non2xx++;
        }
      } catch (_) {
        stats.errors++;
      } finally {
        socket.destroy();
      }
    }
  }

  await Future.wait([
    for (var i = 0; i < options.connectionsOf(index); i++) connection(),
  ]);
  Isolate.exit(results, stats.toMessage());
}

/// Reads HTTP/1.1 responses from a socket, one at a time.
class _ResponseReader {
  Uint8List _buffer = Uint8List(16 * 1024);
  int _start = 0;
  int _end = 0;
  Completer<int>? _waiting;
  Object? _error;

  _ResponseReader(Socket socket) {
    socket.listen(
      _onData,
      onError: (Object e) => _fail(e),
      onDone: () => _fail(const SocketException('closed by the server')),
    );
  }

  /// The status code of the next response, once it has been read whole.
  Future<int> next() {
    var error = _error;
    if (error != null) return Future.error(error);
    var status = _parse();
    if (status >= 0) return Future.value(status);
    return (_waiting = Completer<int>()).future;
  }

  void _fail(Object e) {
    _error ??= e;
    var waiting = _waiting;
    _waiting = null;
    waiting?.completeError(e);
  }

  void _onData(Uint8List data) {
    if (_end + data.length > _buffer.length) {
      var live = _end - _start;
      var size = _buffer.length;
      while (size < live + data.length) {
        size *= 2;
      }
      var grown = Uint8List(size)..setRange(0, live, _buffer, _start);
      _buffer = grown;
      _start = 0;
      _end = live;
    }
    _buffer.setRange(_end, _end + data.length, data);
    _end += data.length;

    var waiting = _waiting;
    if (waiting == null) return;
    int status;
    try {
      status = _parse();
    } catch (e) {
      _fail(e);
      return;
    }
    if (status >= 0) {
      _waiting = null;
      waiting.complete(status);
    }
  }

  /// Consumes one whole response and returns its status, or returns -1 if
  /// it has not all arrived yet.
  int _parse() {
    var headersEnd = _indexOfCrlfCrlf(_start);
    if (headersEnd < 0) return -1;
    var head = latin1.decode(
      Uint8List.sublistView(_buffer, _start, headersEnd),
    );
    var status = int.parse(head.substring(9, 12));
    var bodyStart = headersEnd + 4;

    var contentLength = 0;
    var chunked = false;
    for (var line in head.split('\r\n').skip(1)) {
      var colon = line.indexOf(':');
      if (colon < 0) continue;
      var name = line.substring(0, colon).toLowerCase();
      var value = line.substring(colon + 1).trim();
      if (name == 'content-length') {
        contentLength = int.parse(value);
      } else if (name == 'transfer-encoding' &&
          value.toLowerCase().contains('chunked')) {
        chunked = true;
      }
    }

    int responseEnd;
    if (chunked) {
      responseEnd = _chunkedEnd(bodyStart);
      if (responseEnd < 0) return -1;
    } else {
      responseEnd = bodyStart + contentLength;
      if (responseEnd > _end) return -1;
    }

    _start = responseEnd;
    if (_start == _end) _start = _end = 0;
    return status;
  }

  /// The end of a chunked body that starts at [at], or -1 if incomplete.
  int _chunkedEnd(int at) {
    var i = at;
    while (true) {
      var lineEnd = _indexOfCrlf(i);
      if (lineEnd < 0) return -1;
      var sizeText = latin1
          .decode(Uint8List.sublistView(_buffer, i, lineEnd))
          .split(';')
          .first
          .trim();
      var size = int.parse(sizeText, radix: 16);
      i = lineEnd + 2;
      if (size == 0) {
        // No trailers are expected: the body ends with an empty line.
        if (i + 2 > _end) return -1;
        return i + 2;
      }
      i += size + 2;
      if (i > _end) return -1;
    }
  }

  int _indexOfCrlf(int from) {
    for (var i = from; i + 1 < _end; i++) {
      if (_buffer[i] == 13 && _buffer[i + 1] == 10) return i;
    }
    return -1;
  }

  int _indexOfCrlfCrlf(int from) {
    for (var i = from; i + 3 < _end; i++) {
      if (_buffer[i] == 13 &&
          _buffer[i + 1] == 10 &&
          _buffer[i + 2] == 13 &&
          _buffer[i + 3] == 10) {
        return i;
      }
    }
    return -1;
  }
}
