import 'package:angel3_orm_generator/src/orm_build_context.dart';
import 'package:angel3_serialize_generator/angel3_serialize_generator.dart';
import 'package:test/test.dart';

void main() {
  test('names tables as earlier versions did', () {
    // As a table of an existing database is named, which the generated class
    // need not be.
    for (var (clazz, table, generated) in [
      ('_User', 'User', 'User'),
      ('UserEntity', 'User', 'User'),
      ('EntityUser', 'User', 'User'),
      ('_UserEntity', 'UserEntity', 'User'),
      ('UserIdentity', 'UserId', 'UserIdentity'),
      ('entityUser', 'User', 'entityUser'),
    ]) {
      expect(legacyModelName(clazz), table, reason: clazz);
      expect(getGeneratedModelClassName(clazz), generated, reason: clazz);
    }
  });
}
