import 'package:angel3_json_god/angel3_json_god.dart' as god;

class A {
  String foo;
  A(this.foo);
}

class B {
  late String hello;
  late A nested;
  B(String hello, String foo) {
    this.hello = hello;
    this.nested = A(foo);
  }
}

void main() {
  print(god.serialize(B("world", "bar")));
}
