import 'package:angel3_json_god/angel3_json_god.dart' as god;
import 'package:test/test.dart';
import 'shared.dart';

main() {
  god.logger.onRecord.listen(printRecord);

  test('fromJson', () {
    var foo = god.deserialize('{"bar":"baz"}', outputType: Foo) as Foo;

    expect(foo is Foo, true);
    expect(foo.text, equals('baz'));
  });

  test('toJson', () {
    var foo = Foo(text: 'baz');
    var data = god.serializeObject(foo);
    expect(data, equals({'bar': 'baz', 'foo': 'poobaz'}));
  });
}

class Foo {
  String? text;

  String get foo => 'poo$text';

  Foo({this.text});

  factory Foo.fromJson(Map json) => Foo(text: json['bar'].toString());

  Map toJson() => {'bar': text, 'foo': foo};
}
