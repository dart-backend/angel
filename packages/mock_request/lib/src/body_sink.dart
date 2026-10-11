import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'lockable_headers.dart';

/// The body of a `MockHttpRequest` or `MockHttpResponse`: a sink that behaves
/// like dart:io's `IOSink`, and the stream of what was written to it. Not
/// exported from the package.
class MockBodySink {
  final String _name;
  final LockableMockHttpHeaders _headers;
  final Encoding Function() _encoding;
  final BytesBuilder _buf;
  final Completer _done = Completer();
  final StreamController<Uint8List> _controller = StreamController();
  Encoding? _writeEncoding;
  bool _isBound = false;
  int _bytesWritten = 0;

  bool _bufferOutput;

  /// Whether [add] holds bytes until [flush] or [close], or sends them on.
  bool get bufferOutput => _bufferOutput;

  /// As in dart:io, it can only change before anything is written.
  set bufferOutput(bool value) {
    if (_bytesWritten > 0 || _done.isCompleted) {
      throw StateError('Header already sent');
    }
    _bufferOutput = value;
  }

  /// [name] is used in error messages. [encoding] gives the encoding for the
  /// first [write]; [copy] corresponds to `copy` on [BytesBuilder].
  MockBodySink(
    String name,
    this._headers,
    Encoding Function() encoding, {
    bool copy = true,
    this._bufferOutput = true,
  }) : _name = name,
       _encoding = encoding,
       _buf = BytesBuilder(copy: copy);

  int get bytesWritten => _bytesWritten;

  /// The encoding [write] kept from the first write, if there was one.
  Encoding? get writeEncoding => _writeEncoding;

  Stream<Uint8List> get stream => _controller.stream;

  Future get done => _done.future;

  // Like dart:io's IOSink: closed and bound sinks reject writes.
  void _checkWritable() {
    if (_isBound) {
      throw StateError('$_name is bound to a stream.');
    } else if (_done.isCompleted) {
      throw StateError('Cannot add to closed $_name.');
    }
  }

  void add(List<int> data) {
    _checkWritable();
    _add(data);
  }

  void _add(List<int> data) {
    _headers.lock();
    _bytesWritten += data.length;
    if (_bufferOutput) {
      _buf.add(data);
    } else {
      _controller.add(data is Uint8List ? data : Uint8List.fromList(data));
    }
  }

  void addError(Object error, [StackTrace? stackTrace]) {
    _checkWritable();
    // Bytes added earlier go first, as in dart:io.
    if (_buf.isNotEmpty) _controller.add(_buf.takeBytes());
    _controller.addError(error, stackTrace);
  }

  /// Completes with the first error from [stream], which then stops adding.
  Future addStream(Stream<List<int>> stream) {
    _checkWritable();
    var c = Completer();
    // Bound before listen, in case the stream finishes during it, and
    // unbound again if listen throws.
    _isBound = true;
    try {
      stream.listen(
        _add,
        onError: (Object error, StackTrace stackTrace) {
          _isBound = false;
          c.completeError(error, stackTrace);
        },
        onDone: () {
          _isBound = false;
          c.complete();
        },
        cancelOnError: true,
      );
    } catch (_) {
      _isBound = false;
      rethrow;
    }
    return c.future;
  }

  /// Can be called more than once; later calls return [done]. [beforeClose]
  /// runs on the first call, before the headers are locked for good.
  Future close({void Function()? beforeClose}) {
    if (_isBound) throw StateError('$_name is bound to a stream.');
    if (!_done.isCompleted) {
      beforeClose?.call();
      _headers.lock();
      if (_buf.isNotEmpty) _controller.add(_buf.takeBytes());
      scheduleMicrotask(_controller.close);
      _done.complete();
    }
    return done;
  }

  Future flush() {
    if (_isBound) throw StateError('$_name is bound to a stream.');
    if (!_done.isCompleted && _buf.isNotEmpty) {
      _controller.add(_buf.takeBytes());
    }
    return Future.value();
  }

  /// Writes [obj] in the encoding in effect at the first write, which is then
  /// kept, as in dart:io; the headers are locked by then anyway.
  void write(Object? obj) {
    // As in dart:io: null writes 'null', and an empty string adds nothing,
    // so the headers stay unlocked.
    var text = '$obj';
    if (text.isEmpty) return;
    var encoding = _writeEncoding ?? _encoding();
    add(encoding.encode(text));
    // Kept only once a write succeeds; a failed one leaves it open.
    _writeEncoding ??= encoding;
  }

  void writeAll(Iterable objects, [String separator = '']) {
    write(objects.join(separator));
  }

  void writeCharCode(int charCode) => write(String.fromCharCode(charCode));

  void writeln([Object? obj = '']) => write('$obj\n');
}
