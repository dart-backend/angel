class ContainerConst {
  static const String defaultErrorMessage =
      'You attempted to perform a reflective action, but you are using `ThrowingReflector`, '
      'a class which disables reflection. Consider using the `MirrorsReflector` '
      'class from package:angel3_container_mirrors if you need reflection.';

  ContainerConst._();
}
