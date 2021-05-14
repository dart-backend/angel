import 'package:angel3_framework/angel3_framework.dart';
import 'package:test/test.dart';

void main() {
  test('default view generator', () async {
    var app = Angel();
    var view = await app.viewGenerator!('foo', {'bar': 'baz'});
    expect(view, contains('No view engine'));
  });
}
