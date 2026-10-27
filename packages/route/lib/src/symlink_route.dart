part of 'router.dart';

/// Placeholder [Route] to serve as a symbolic link
/// to a mounted [Router].
class SymlinkRoute<T> extends Route<T> {
  final Router<T> router;

  /// Middleware for this link only (e.g. from a chain the router was mounted
  /// on), run before [router]'s own middleware. Unlike that, it does not
  /// apply where [router] is mounted elsewhere.
  final List<T> middleware;

  SymlinkRoute(super.path, this.router, {Iterable<T> middleware = const []})
    : middleware = List.unmodifiable(middleware),
      super(method: 'GET', handlers: <T>[]);
}
