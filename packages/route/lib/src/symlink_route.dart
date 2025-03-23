part of 'router.dart';

/// Placeholder [Route] to serve as a symbolic link
/// to a mounted [Router].
class SymlinkRoute<T> extends Route<T> {
  final Router<T> router;
  SymlinkRoute(super.path, this.router) : super(method: 'GET', handlers: <T>[]);
}
