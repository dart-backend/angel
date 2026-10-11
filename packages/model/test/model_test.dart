import 'package:angel3_model/angel3_model.dart';
import 'package:test/test.dart';

void main() {
  test('none is the canonical None', () {
    expect(none, isA<None>());
    expect(identical(none, const None()), isTrue);
  });

  test('idAsInt parses the id, or is -1', () {
    expect(Model(id: '42').idAsInt, 42);
    expect(Model(id: 'abc').idAsInt, -1);
    expect(Model().idAsInt, -1);
  });
}
