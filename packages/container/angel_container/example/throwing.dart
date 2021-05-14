import 'package:angel3_container/angel3_container.dart';

void main() {
  var reflector = const ThrowingReflector();
  reflector.reflectClass(StringBuffer);
}
