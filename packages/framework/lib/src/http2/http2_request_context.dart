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
  HttpSession Function()? _createSession;
  void Function()? _onClose;

  Http2RequestContext._(this.container);

  @override
  Stream<List<int>> get body => _body.stream;

  static Future<Http2RequestContext> from(
    ServerTransportStream stream,
    Socket socket,
    Angel app,
    Map<String, MockHttpSession> sessions,
    Uuid uuid, {
    void Function(MockHttpSession session)? onSessionCreated,
  }) {
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
      if (req._method == null || req._path == null) {
        throw AngelHttpException.badRequest(
          message: 'Missing :method or :path pseudo-header.',
        );
      }
      req
        .._cookies = List.unmodifiable(cookies)
        .._uri = uri;

      // Apply the session only now that the cookie headers have been read.
      // An unknown id gets a fresh session rather than adopting the
      // client-chosen id, which would allow session fixation.
      var sessionId = cookies
          .firstWhereOrNull((c) => c.name == 'DARTSESSID')
          ?.value;
      req._session = sessionId == null ? null : sessions[sessionId];
      // A new session is only created once `session` is read, like dart:io:
      // creating one per cookie-less request would let any client fill the
      // session store until the sessions expire.
      req._createSession = () {
        var id = uuid.v4();
        var session = sessions[id] = MockHttpSession(id: id);
        onSessionCreated?.call(session);
        return session;
      };

      c.complete(req);
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

    // Body data is read only as fast as the handler consumes it, so an
    // unread or slowly read body is held back by HTTP/2 flow control rather
    // than buffered in memory. Once nobody can read it any more, it is
    // drained and discarded.
    late StreamSubscription<StreamMessage> sub;
    var waitingForReader = false, pausedByReader = false;
    void stopWaiting() {
      if (waitingForReader) {
        waitingForReader = false;
        sub.resume();
      }
    }

    void readerResumed() {
      if (pausedByReader) {
        pausedByReader = false;
        sub.resume();
      }
    }

    // A reader that cancels while paused (e.g. a body rejected mid-parse)
    // never resumes, so cancelling and closing release its pause too.
    void stopReading() {
      stopWaiting();
      readerResumed();
    }

    req._body
      ..onListen = stopWaiting
      ..onPause = () {
        if (!pausedByReader) {
          pausedByReader = true;
          sub.pause();
        }
      }
      ..onResume = readerResumed
      ..onCancel = stopReading;

    void fail(Object error, StackTrace stackTrace) {
      if (!c.isCompleted) {
        c.completeError(error, stackTrace);
        // No request context will read or close the body, so discard the
        // rest of it; holding it back would stall the stream's flow control.
        req._body.close();
        stopReading();
      } else if (!req._body.isClosed) {
        req._body.addError(error, stackTrace);
      }
    }

    sub = stream.incomingMessages.listen(
      (msg) {
        // Nothing may throw out of this listener: it runs outside the
        // request's error zone, so an exception here would be unhandled
        // and terminate the whole server.
        try {
          if (msg is DataStreamMessage) {
            finalize();
            if (!req._body.isClosed) {
              // Kept even while waiting, so no body bytes are ever lost.
              req._body.add(msg.bytes);
              if (!req._body.hasListener && !waitingForReader) {
                // Wait for the handler to read the body (or close the request).
                waitingForReader = true;
                sub.pause();
              }
            }
          } else if (msg is HeadersStreamMessage) {
            if (c.isCompleted) {
              // Trailers: they must not change the request, which is already
              // being handled, and are not exposed.
              return;
            }
            msg.headers.forEach(handleHeader);
            if (msg.endStream) finalize();
          }
        } catch (e, st) {
          fail(e, st);
        }
      },
      onDone: () {
        try {
          finalize();
        } catch (e, st) {
          fail(e, st);
        }
        req._body.close();
      },
      cancelOnError: true,
      onError: fail,
    );
    req._onClose = stopReading;

    return c.future;
  }

  @override
  List<Cookie> get cookies => _cookies;

  /// The underlying HTTP/2 [ServerTransportStream].
  ServerTransportStream? get stream => _stream;

  @override
  Uri? get uri => _uri;

  /// The user's HTTP session, created on first access if the client did not
  /// send the id of an existing one.
  @override
  HttpSession? get session => _session ??= _createSession?.call();

  /// Whether this request has a session, without creating one.
  bool get hasSession => _session != null;

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
    _onClose?.call();
    return super.close();
  }

  @override
  ServerTransportStream? get rawRequest => _stream;
}
