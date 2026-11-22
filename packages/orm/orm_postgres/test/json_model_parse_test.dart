import 'package:test/test.dart';

import 'models/profile_user.dart';

/// How a field of a `@serializable` class is read from a row, as each
/// database gives JSON: PostgreSQL as a map, MySQL and SQLite as text.
void main() {
  List<Object?> row({
    Object? profile,
    Object? address = '{"city":"Lisbon"}',
  }) => ['1', null, null, 'ana', profile, address];

  test('of a map', () {
    var user = ProfileUserQuery()
        .parseRow(row(profile: {'first_name': 'Ana', 'last_name': 'Silva'}))
        .value;
    expect(user.profile, UserProfile(firstName: 'Ana', lastName: 'Silva'));
  });

  test('of JSON text', () {
    var user = ProfileUserQuery()
        .parseRow(row(profile: '{"first_name":"Ana","last_name":"Silva"}'))
        .value;
    expect(user.profile, UserProfile(firstName: 'Ana', lastName: 'Silva'));
    expect(user.address, UserAddress(city: 'Lisbon'));
  });

  test('of NULL', () {
    var user = ProfileUserQuery().parseRow(row()).value;
    expect(user.profile, isNull);
  });

  test('of NULL, of a non-nullable one, throws', () {
    expect(
      () => ProfileUserQuery().parseRow(row(address: null)),
      throwsA(isA<TypeError>()),
    );
  });

  test('not selected, of a non-nullable one, throws', () {
    var query = ProfileUserQuery()..select(['name', 'profile']);
    expect(() => query.parseRow(['ana', null]), throwsA(isA<StateError>()));
  });
}
