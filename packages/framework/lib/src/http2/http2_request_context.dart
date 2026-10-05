import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:angel3_container/angel3_container.dart';
import 'package:angel3_framework/angel3_framework.dart' hide Header;
import 'package:collection/collection.dart' show IterableExtension;
import 'package:http2/transport.dart';
import 'package:angel3_mock_request/angel3_mock_request.dart';
import 'package:uuid/uuid.dart';

final RegExp _straySlashes = RegExp(r'(^/+)|(/+$)');

class Http2RequestContext extends RequestContext<ServerTransportStream?> {
  final StreamController<List<int>> _body = StreamController();
  @override
  final Container container;
  List<Cookie> _cookies = <Cookie>[];
  HttpHeaders? _headers;
  String? _method, _override, _path;
  late Socket _socket;
  ServerTransportStream? _stream;
  Uri? _uri;
  HttpSession? _session;

  Http2RequestContext._(this.container);

  @override
  Stream<List<int>> get body => _body.stream;

  static Future<Http2RequestContext> from(
    ServerTransportStream stream,
    Socket socket,
    Angel app,
    Map<String, MockHttpSession> sessions,
    Uuid uuid,
  ) {
    var c = Completer<Http2RequestContext>();
    var req = Http2RequestContext._(app.container.createChild())
      ..app = app
      .._socket = socket
      .._stream = stream;

    var headers = req._headers = MockHttpHeaders();
    // String scheme = 'https', host = socket.address.address, path = '';
    var uri = Uri(
      scheme: 'https',
      host: socket.address.address,
      port: socket.port,
    );
    var cookies = <Cookie>[];

    void finalize() {
      if (c.isCompleted) return;
      req
        .._cookies = List.unmodifiable(cookies)
        .._uri = uri;

      // Apply the session only now that the cookie headers have been read.
      // An unknown id gets a fresh session rather than adopting the
      // client-chosen id, which would allow session fixation.
      var sessionId = cookies
          .firstWhereOrNull((c) => c.name == 'DARTSESSID')
          ?.value;
      var session = sessionId == null ? null : sessions[sessionId];
      if (session == null) {
        var id = uuid.v4();
        session = sessions[id] = MockHttpSession(id: id);
      }
      req._session = session;

      c.complete(req);
    }

    void fail(Object error, StackTrace stackTrace) {
      if (!c.isCompleted) {
        c.completeError(error, stackTrace);
      } else if (!req._body.isClosed) {
        req._body.addError(error, stackTrace);
      }
    }

    void parseHost(String value) {
      // Parse as an authority ("host[:port]"), not as a full URI, where
      // "example.com:8443" would be read as a scheme.
      var inUri = Uri.tryParse('//$value');
      if (inUri == null || inUri.host.isEmpty) return;
      uri = uri.replace(host: inUri.host);
      if (inUri.hasPort) uri = uri.replace(port: inUri.port);
    }

    void handleHeader(Header header) {
      // Header bytes come straight from the client: decode them without
      // throwing (Latin-1 accepts every byte, matching dart:io), and do not
      // percent-decode or comma-split values, which would corrupt them.
      var name = latin1.decode(header.name).toLowerCase();
      var value = latin1.decode(header.value);

      switch (name) {
        case ':method':
          req._method = value;
          break;
        case ':path':
          var inUri = Uri.tryParse(value);
          if (inUri == null) {
            throw AngelHttpException.badRequest(message: 'Invalid :path.');
          }
          uri = uri.replace(path: inUri.path);
          if (inUri.hasQuery) uri = uri.replace(query: inUri.query);
          var path = uri.path.replaceAll(_straySlashes, '');
          req._path = path;
          if (path.isEmpty) req._path = '/';
          break;
        case ':scheme':
          uri = uri.replace(scheme: value);
          break;
        case ':authority':
          // HTTP/2 clients send :authority instead of Host.
          parseHost(value);
          if (headers.value('host') == null) headers.set('host', value);
          break;
        case 'cookie':
          var cookieStrings = value.split(';').map((s) => s.trim());

          for (var cookieString in cookieStrings) {
            try {
              cookies.add(Cookie.fromSetCookieValue(cookieString));
            } catch (_) {
              // Ignore malformed cookies, and just don't add them to the container.
            }
          }
          break;
        case 'host':
          parseHost(value);
          headers.set('host', value);
          break;
        default:
          headers.add(name, value);
          break;
      }
    }

    stream.incomingMessages.listen(
      (msg) {
        // Nothing may throw out of this listener: it runs outside the
        // request's error zone, so an exception here would be unhandled
        // and terminate the whole server.
        try {
          if (msg is DataStreamMessage) {
            finalize();
            req._body.add(msg.bytes);
          } else if (msg is HeadersStreamMessage) {
            msg.headers.forEach(handleHeader);
            if (msg.endStream) finalize();
          }
        } catch (e, st) {
          fail(e, st);
        }
      },
      onDone: () {
        finalize();
        req._body.close();
      },
      cancelOnError: true,
      onError: fail,
    );

    return c.future;
  }

  @override
  List<Cookie> get cookies => _cookies;

  /// The underlying HTTP/2 [ServerTransportStream].
  ServerTransportStream? get stream => _stream;

  @override
  Uri? get uri => _uri;

  @override
  HttpSession? get session {
    return _session;
  }

  @override
  InternetAddress get remoteAddress => _socket.remoteAddress;

  @override
  String get path {
    return _path ?? '';
  }

  @override
  String get originalMethod {
    return _method ?? 'GET';
  }

  @override
  String get method {
    return _override ?? _method ?? 'GET';
  }

  @override
  String get hostname => _headers?.value('host') ?? 'localhost';

  @override
  HttpHeaders? get headers => _headers;

  @override
  Future close() {
    _body.close();
    return super.close();
  }

  @override
  ServerTransportStream? get rawRequest => _stream;
}
