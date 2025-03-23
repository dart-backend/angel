import 'dart:typed_data';

import 'package:test/test.dart';
import 'models/with_enum.dart';

WithEnum aWithEnum = WithEnum(type: WithEnumType.a);
WithEnum aWithEnum2 = WithEnum(type: WithEnumType.a);

void main() {
  test('enum serializes to int', () {
    var w = WithEnum(type: WithEnumType.b).toJson();
    print(w);
    var enumType = w[WithEnumFields.type] as WithEnumType;
    expect(enumType.index, WithEnumType.values.indexOf(WithEnumType.b));
  });

  test('enum serializes null if null', () {
    var w = WithEnum(type: null).toJson();
    expect(w[WithEnumFields.type], null);
  });

  test('enum deserializes to default value from null', () {
    var map = {WithEnumFields.type: null};
    var w = WithEnumSerializer.fromMap(map);
    expect(w.type, WithEnumType.b);
  });

  test('enum deserializes from int', () {
    var map = {WithEnumFields.type: WithEnumType.b};
    var w = WithEnumSerializer.fromMap(map);
    expect(w.type, WithEnumType.b);
  });

  test('enum deserializes from value', () {
    var map = {WithEnumFields.type: WithEnumType.c};
    var w = WithEnumSerializer.fromMap(map);
    expect(w.type, WithEnumType.c);
  });

  test('equality', () {
    expect(WithEnum(type: WithEnumType.a), WithEnum(type: WithEnumType.a));
    expect(
        WithEnum(type: WithEnumType.a), isNot(WithEnum(type: WithEnumType.b)));
  });

  test('const', () {
    print('aWithEnum ${aWithEnum.hashCode}');
    print('aWithEnum2 ${aWithEnum2.hashCode}');

    //expect(identical(aWithEnum, aWithEnum2), true);
    expect(aWithEnum == aWithEnum2, true);
  });

  test('uint8list', () {
    var ee = WithEnum(
        imageBytes: Uint8List.fromList(List<int>.generate(1000, (i) => i)));
    var eeMap = ee.toJson();
    print(ee);
    var ef = WithEnumSerializer.fromMap(eeMap);
    expect(ee.copyWith(), ee);
    expect(ef, ee);
  });
}
