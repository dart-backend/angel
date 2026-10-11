import 'dart:convert';
import 'dart:io';

import 'package:charcode/ascii.dart';

class MockHttpHeaders implements HttpHeaders {
  final Map<String, List<String>> _data = {};
  final List<String> _noFolding = [];
  //Uri? _host;
  String? _hostname;
  int _port = 80;

  List<String> get doNotFold => List<String>.unmodifiable(_noFolding);

  // Null when absent, and setting null removes it, as in dart:io.
  @override
  ContentType? get contentType =>
      _data.containsKey(HttpHeaders.contentTypeHeader)
      ? ContentType.parse(_data[HttpHeaders.contentTypeHeader]!.join(','))
      : null;

  @override
  set contentType(ContentType? value) => value == null
      ? removeAll(HttpHeaders.contentTypeHeader)
      : set(HttpHeaders.contentTypeHeader, value.toString());

  // Absent headers are null, as in dart:io; not the current time.
  @override
  DateTime? get date => _data.containsKey(HttpHeaders.dateHeader)
      ? HttpDate.parse(_data[HttpHeaders.dateHeader]!.join(','))
      : null;

  @override
  set date(DateTime? value) => _setDate(HttpHeaders.dateHeader, value);

  // Absent headers are null, as in dart:io; not the current time.
  @override
  DateTime? get expires => _data.containsKey(HttpHeaders.expiresHeader)
      ? HttpDate.parse(_data[HttpHeaders.expiresHeader]!.join(','))
      : null;

  @override
  set expires(DateTime? value) => _setDate(HttpHeaders.expiresHeader, value);

  // Absent headers are null, as in dart:io; not the current time.
  @override
  DateTime? get ifModifiedSince =>
      _data.containsKey(HttpHeaders.ifModifiedSinceHeader)
      ? HttpDate.parse(_data[HttpHeaders.ifModifiedSinceHeader]!.join(','))
      : null;

  @override
  set ifModifiedSince(DateTime? value) =>
      _setDate(HttpHeaders.ifModifiedSinceHeader, value);

  // Setting null removes the header, as in dart:io.
  void _setDate(String name, DateTime? value) =>
      value == null ? removeAll(name) : set(name, HttpDate.format(value));

  @override
  String? get host {
    return _hostname;
    /*
    if (_host != null) {
      return _host!.host;
    } else if (_data.containsKey(HttpHeaders.hostHeader)) {
      _host = Uri.parse(_data[HttpHeaders.hostHeader]!.join(','));
      return _host!.host;
    } else {
      return null;
    }
    */
  }

  @override
  int get port {
    return _port;
  }

  @override
  List<String>? operator [](String name) => _data[name.toLowerCase()];

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    if (name.toLowerCase() == HttpHeaders.contentLengthHeader) {
      return _setContentLength(value);
    }
    var lower = preserveHeaderCase ? name : name.toLowerCase();

    if (_data.containsKey(lower)) {
      if (value is Iterable) {
        _data[lower]!.addAll(value.map((x) => x.toString()).toList());
      } else {
        _data[lower]!.add(value.toString());
      }
    } else {
      if (value is Iterable) {
        _data[lower] = value.map((x) => x.toString()).toList();
      } else {
        _data[lower] = [value.toString()];
      }
    }
  }

  @override
  void clear() {
    _data.clear();
  }

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _data.forEach(action);
  }

  @override
  void noFolding(String name) {
    _noFolding.add(name.toLowerCase());
  }

  @override
  void remove(String name, Object value) {
    var lower = name.toLowerCase();

    if (_data.containsKey(lower)) {
      if (value is Iterable) {
        for (var x in value) {
          _data[lower]!.remove(x.toString());
        }
      } else {
        _data[lower]!.remove(value.toString());
      }
      // As in dart:io, a header with no values left is gone.
      if (_data[lower]!.isEmpty) _data.remove(lower);
    }
  }

  @override
  void removeAll(String name) {
    _data.remove(name.toLowerCase());
  }

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    if (name.toLowerCase() == HttpHeaders.contentLengthHeader) {
      return _setContentLength(value, replace: true);
    }
    var lower = preserveHeaderCase ? name : name.toLowerCase();
    _data.remove(lower);

    if (value is Iterable) {
      _data[lower] = value.map((x) => x.toString()).toList();
    } else {
      _data[lower] = [value.toString()];
    }
  }

  // As in dart:io: content-length holds one value of digits, and a later value
  // replaces an earlier one. All values are checked before any is stored.
  void _setContentLength(Object? value, {bool replace = false}) {
    var values = value is Iterable ? value.toList() : [value];
    var lengths = values.map(_parseContentLength).toList();
    if (lengths.isNotEmpty) {
      _data[HttpHeaders.contentLengthHeader] = ['${lengths.last}'];
    } else if (replace) {
      _data.remove(HttpHeaders.contentLengthHeader);
    }
  }

  static int _parseContentLength(Object? value) {
    var text = switch (value) {
      int() => '$value',
      String() => value,
      _ => throw HttpException(
        'Unexpected type for header named ${HttpHeaders.contentLengthHeader}',
      ),
    };
    if (text.isEmpty || text.codeUnits.any((c) => c < $0 || c > $9)) {
      throw HttpException('Content-Length must contain only digits');
    }
    var leadingZeros = 0;
    while (leadingZeros < text.length - 1 && text[leadingZeros] == '0') {
      leadingZeros++;
    }
    if (text.length - leadingZeros >= 16) {
      throw HttpException('Content-Length too large');
    }
    return int.parse(text);
  }

  @override
  String? value(String name) => _data[name.toLowerCase()]?.join(',');

  @override
  String toString() {
    var b = StringBuffer();
    _data.forEach((k, v) {
      b.write('$k: ');
      b.write(v.join(','));
      b.writeln();
    });
    return b.toString();
  }

  @override
  bool chunkedTransferEncoding = false;

  // Backed by the content-length header, as in dart:io; -1 when it is absent.
  @override
  int get contentLength =>
      int.tryParse(value(HttpHeaders.contentLengthHeader) ?? '') ?? -1;

  @override
  set contentLength(int value) => value < 0
      ? removeAll(HttpHeaders.contentLengthHeader)
      : set(HttpHeaders.contentLengthHeader, value);

  @override
  bool persistentConnection = true;

  @override
  set host(String? host) {
    _hostname = host;
  }

  @override
  set port(int? port) {
    _port = port ?? 80;
  }
}

/// The [Encoding] named by the charset in the content-type header of
/// [headers], or null. Hidden from the package's exports.
Encoding? charsetEncoding(HttpHeaders headers) {
  var charset = headers.contentType?.charset;
  return charset == null ? null : Encoding.getByName(charset);
}
