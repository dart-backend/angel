library;

import 'package:angel3_http_exception/angel3_http_exception.dart';

import 'hooked_service.dart' show HookedServiceEventListener;
import 'request_context.dart';
import 'routable.dart';

/// Annotation to map middleware onto a handler.
class Middleware {
  final Iterable<RequestHandler> handlers;

  const Middleware(this.handlers);
}

/// Attaches hooks to a [HookedService].
class Hooks {
  final List<HookedServiceEventListener> before;
  final List<HookedServiceEventListener> after;

  const Hooks({this.before = const [], this.after = const []});
}

/// Specifies to NOT expose a method to the Internet.
class NoExpose {
  const NoExpose();
}

const NoExpose noExpose = NoExpose();

/// Exposes a [Controller] or a [Controller] method to the Internet.
/// Example:
///
/// ```dart
/// @Expose('/elements')
/// class ElementController extends Controller {
///
///   @Expose('/')
///   List<Element> getList() => someComputationHere();
///
///   @Expose('/int:elementId')
///   getElement(int elementId) => someOtherComputation();
///
/// }
/// ```
class Expose {
  final String method;
  final String path;
  final Iterable<RequestHandler> middleware;
  final String? as;
  final List<String> allowNull;

  static const Expose get = Expose('', method: 'GET'),
      post = Expose('', method: 'POST'),
      patch = Expose('', method: 'PATCH'),
      put = Expose('', method: 'PUT'),
      delete = Expose('', method: 'DELETE'),
      head = Expose('', method: 'HEAD');

  const Expose(this.path,
      {this.method = 'GET',
      this.middleware = const [],
      this.as,
      this.allowNull = const []});

  const Expose.method(this.method,
      {this.middleware = const [], this.as, this.allowNull = const []})
      : path = '';
}

/// Used to apply special dependency injections or functionality to a function parameter.
class Parameter {
  /// Inject the value of a request cookie.
  final String? cookie;

  /// Inject the value of a request header.
  final String? header;

  /// Inject the value of a key from the session.
  final String? session;

  /// Inject the value of a key from the query.
  final String? query;

  /// Only execute the handler if the value of this parameter matches the given value.
  final dynamic match;

  /// Specify a default value.
  final dynamic defaultValue;

  /// If `true` (default), then an error will be thrown if this parameter is not present.
  final bool required;

  const Parameter(
      {this.cookie,
      this.query,
      this.header,
      this.session,
      this.match,
      this.defaultValue,
      this.required = true});

  /// Returns an error that can be thrown when the parameter is not present.
  Object? get error {
    if (cookie?.isNotEmpty == true) {
      return AngelHttpException.badRequest(
          message: 'Missing required cookie "$cookie".');
    }
    if (header?.isNotEmpty == true) {
      return AngelHttpException.badRequest(
          message: 'Missing required header "$header".');
    }
    if (query?.isNotEmpty == true) {
      return AngelHttpException.badRequest(
          message: 'Missing required query parameter "$query".');
    }
    if (session?.isNotEmpty == true) {
      return StateError('Session does not contain required key "$session".');
    }

    return null;
  }

  /// Obtains a value for this parameter from a [RequestContext].
  dynamic getValue(RequestContext req) {
    if (cookie?.isNotEmpty == true) {
      return req.cookies.firstWhere((c) => c.name == cookie).value;
    }
    if (header?.isNotEmpty == true) {
      return req.headers?.value(header ?? '') ?? defaultValue;
    }
    if (session?.isNotEmpty == true) {
      return req.session?[session] ?? defaultValue;
    }
    if (query?.isNotEmpty == true) {
      return req.uri?.queryParameters[query] ?? defaultValue;
    }
    return defaultValue;
  }
}

/// Shortcut for declaring a request header [Parameter].
class Header extends Parameter {
  const Header(String header, {super.match, super.defaultValue, super.required})
      : super(header: header);
}

/// Shortcut for declaring a request session [Parameter].
class Session extends Parameter {
  const Session(String session,
      {super.match, super.defaultValue, super.required})
      : super(session: session);
}

/// Shortcut for declaring a request query [Parameter].
class Query extends Parameter {
  const Query(String query, {super.match, super.defaultValue, super.required})
      : super(query: query);
}

/// Shortcut for declaring a request cookie [Parameter].
class CookieValue extends Parameter {
  const CookieValue(String cookie,
      {super.match, super.defaultValue, super.required})
      : super(cookie: cookie);
}
