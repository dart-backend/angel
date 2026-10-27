/// A `dart:mirrors` backend for `package:angel3_container`.
///
/// `dart:mirrors` is only available on the Dart VM in JIT mode, so apps
/// compiled ahead of time (e.g. with `dart compile exe`) should mark their
/// classes `@injectable`, generate their reflection data with
/// `package:angel3_container_generator`, and use
/// `StaticReflector.combine([...])`; or register everything and use
/// `EmptyReflector`.
library;

export 'src/reflector.dart';
