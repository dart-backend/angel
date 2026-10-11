/// A `dart:mirrors` backend for `package:angel3_container`.
///
/// `dart:mirrors` is only available on the Dart VM in JIT mode, so apps
/// compiled ahead of time (e.g. with `dart compile exe`) should use
/// `GeneratedReflector` from `package:angel3_container_generator`, or
/// register everything and use `EmptyReflector`.
library;

export 'src/reflector.dart';
