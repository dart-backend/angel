import 'dart:async';

import 'package:angel3_container/angel3_container.dart';
import 'package:angel3_route/angel3_route.dart';
import 'package:logging/logging.dart';

import 'env.dart';
import 'hostname_parser.dart';
import 'request_context.dart';
import 'response_context.dart';
import 'routable.dart';
import 'server.dart';

/// A utility that allows requests to be handled based on their
/// origin's hostname.
///
/// For example, an application could handle example.com and api.example.com
/// separately.
///
/// The provided patterns can be any `Pattern`. If a `String` is provided, a simple
/// grammar (see [HostnameSyntaxParser]) is used to create [RegExp].
///
/// For example:
/// * `example.com` -> `/example\.com/`
/// * `*.example.com` -> `/([^$.]\.)?example\.com/`
/// * `example.*` -> `/example\./[^$]*`
/// * `example.+` -> `/example\./[^$]+`
class HostnameRouter {
  final Map<Pattern, Angel> _apps = {};
  final Map<Pattern, FutureOr<Angel> Function()> _creators = {};
  final Map<Pattern, Future<Angel>> _pending = {};
  final List<Pattern> _patterns = [];

  HostnameRouter({
    Map<Pattern, Angel> apps = const {},
    Map<Pattern, FutureOr<Angel> Function()> creators = const {},
  }) {
    Map<Pattern, V> parseMap<V>(Map<Pattern, V> map) {
      return map.map((p, c) {
        Pattern pp;

        if (p is String) {
          pp = HostnameSyntaxParser(p).parse();
        } else {
          pp = p;
        }

        return MapEntry(pp, c);
      });
    }

    apps = parseMap(apps);
    creators = parseMap(creators);
    var patterns = apps.keys.followedBy(creators.keys).toSet().toList();
    _apps.addAll(apps);
    _creators.addAll(creators);
    _patterns.addAll(patterns);
    // print(_creators);
  }

  factory HostnameRouter.configure(
    Map<Pattern, FutureOr<void> Function(Angel)> configurers, {
    Reflector reflector = const EmptyReflector(),
    AngelEnvironment environment = angelEnv,
    Logger? logger,
    bool allowMethodOverrides = true,
    FutureOr<String> Function(dynamic)? serializer,
    ViewGenerator? viewGenerator,
  }) {
    var creators = configurers.map((p, c) {
      return MapEntry(p, () async {
        var app = Angel(
          reflector: reflector,
          environment: environment,
          logger: logger,
          allowMethodOverrides: allowMethodOverrides,
          serializer: serializer,
          viewGenerator: viewGenerator,
        );
        await app.configure(c);
        return app;
      });
    });
    return HostnameRouter(creators: creators);
  }

  /// Returns [host] without a trailing `:port`, handling IPv6 literals
  /// such as `[::1]:8080`.
  static String _stripPort(String host) {
    if (host.startsWith('[')) {
      var end = host.indexOf(']');
      return end == -1 ? host : host.substring(0, end + 1);
    }
    var colon = host.lastIndexOf(':');
    return colon == -1 ? host : host.substring(0, colon);
  }

  bool _matches(Pattern pattern, String host) {
    // `Host` usually carries a port (e.g. `example.com:8080`). Try the full
    // value first, so patterns that name a port keep working, then the bare
    // hostname.
    if (pattern.allMatches(host).isNotEmpty) return true;
    var bare = _stripPort(host);
    return bare != host && pattern.allMatches(bare).isNotEmpty;
  }

  /// Returns the app for [pattern], creating it at most once even when
  /// several requests arrive before the first creation finishes.
  Future<Angel> _appFor(Pattern pattern) async {
    var app = _apps[pattern];
    if (app != null) return app;
    // Block body: returning the removed future from whenComplete would make
    // the future wait on itself.
    var pending = _pending[pattern] ??= Future.sync(_creators[pattern]!)
        .whenComplete(() {
          _pending.remove(pattern);
        });
    return _apps[pattern] = await pending;
  }

  /// Attempts to handle a request, according to its hostname.
  ///
  /// If none is matched, then `true` is returned.
  /// Also returns `true` if all of the sub-app's handlers returned
  /// `true`.
  Future<bool> handleRequest(RequestContext req, ResponseContext res) async {
    for (var pattern in _patterns) {
      if (_matches(pattern, req.hostname)) {
        // Resolve the entire pipeline within the context of the selected app.
        var app = await _appFor(pattern);

        var r = app.optimizedRouter;
        var resolved = r.resolveAbsolute(req.path, method: req.method);
        for (var result in resolved) {
          req.params.addAll(result.allParams);
        }
        var pipeline = MiddlewarePipeline<RequestHandler>(resolved);
        // print('Pipeline: $pipeline');
        for (var handler in pipeline.handlers) {
          // print(handler);
          // Avoid stack overflow.
          if (handler == handleRequest) {
            continue;
          } else if (!await app.executeHandler(handler, req, res)) {
            // print('$handler TERMINATED');
            return false;
          } else {
            // print('$handler CONTINUED');
          }
        }
      }
    }

    // Otherwise, return true.
    return true;
  }
}
