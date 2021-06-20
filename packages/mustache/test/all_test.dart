import 'dart:async';
import 'package:angel_framework/angel_framework.dart';
import 'package:angel_mustache/angel_mustache.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:test/test.dart';

void main() async {
  var angel = Angel();
  await angel.configure(mustache(const LocalFileSystem().directory('./test')));

  test('can render templates', () async {
    var hello = await angel.viewGenerator!('hello', {'name': 'world'});
    var bar = await angel.viewGenerator!('foo/bar', {'framework': 'angel'});

    expect(hello, equals('Hello, world!'));
    expect(bar, equals('angel_framework'));
  });

  test('throws if view is not found', () {
    expect(Future(() async {
      var fails = await angel.viewGenerator!('fail', {'this_should': 'fail'});
      print(fails);
    }), throwsA(isA<FileSystemException>()));
  });

  test('partials', () async {
    var withPartial = await angel.viewGenerator!('with-partial');
    expect(withPartial, equals('Hello, world!'));
  });
}
