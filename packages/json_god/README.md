# angel3_json_god

[![version](https://img.shields.io/badge/pub-v4.0.3-brightgreen)](https://pub.dartlang.org/packages/angel3_json_god)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/angel_dart/discussion)](https://gitter.im/angel_dart/discussion)

[![License](https://img.shields.io/github/license/dukefirehawk/angel)](https://github.com/dukefirehawk/angel/tree/angel3/packages/json_god/LICENSE)

**DEPRECATED: Replaced by [`belatuk_json_serializer`](https://pub.dartlang.org/packages/belatuk_json_serializer) package**

The ***new and improved*** definitive solution for JSON in Dart. It supports synchronously transform an object into a JSON string and also deserialize a JSON string back into an instance of any type.

## Installation

  dependencies:
      angel3_json_god: ^4.0.0

## Usage

It is recommended to import the library under an alias, i.e., `god`.

```dart
import 'package:angel3_json_god/angel3_json_god.dart' as god;
```

## Serializing JSON

Simply call `god.serialize(x)` to synchronously transform an object into a JSON
string.

```dart
Map map = {"foo": "bar", "numbers": [1, 2, {"three": 4}]};

// Output: {"foo":"bar","numbers":[1,2,{"three":4]"}
String json = god.serialize(map);
print(json);
```

You can easily serialize classes, too. JSON God also supports classes as members.

```dart

class A {
    String foo;
    A(this.foo);
}

class B {
    late String hello;
    late A nested;
    B(String hello, String foo) {
      this.hello = hello;
      this.nested =  A(foo);
    }
}

main() {
    print(god.serialize( B("world", "bar")));
}

// Output: {"hello":"world","nested":{"foo":"bar"}}
```

If a class has a `toJson` method, it will be called instead.

## Deserializing JSON

Deserialization is equally easy, and is provided through `god.deserialize`.

```dart
Map map = god.deserialize('{"hello":"world"}');
int three = god.deserialize("3");
```

### Deserializing to Classes

JSON God lets you deserialize JSON into an instance of any type. Simply pass the
type as the second argument to `god.deserialize`.

If the class has a `fromJson` constructor, it will be called instead.

```dart
class Child {
  String foo;
}

class Parent {
  String hello;
  Child child =  Child();
}

main() {
  God god =  God();
  Parent parent = god.deserialize('{"hello":"world","child":{"foo":"bar"}}', Parent);
  print(parent);
}
```

**Any JSON-deserializable classes must initializable without parameters.
If `Foo()` would throw an error, then you can't use Foo with JSON.**

This allows for validation of a sort, as only fields you have declared will be
accepted.

```dart
class HasAnInt { int theInt; }

HasAnInt invalid = god.deserialize('["some invalid input"]', HasAnInt);
// Throws an error
```

An exception will be thrown if validation fails.
