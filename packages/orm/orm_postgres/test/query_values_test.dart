import 'package:test/test.dart';

import 'models/relation_keys.dart';

/// Tests of the generated query values, which need no database.
void main() {
  test('the key of a relation is null until it is set, and can be cleared', () {
    var values = LoginQuery().values;
    expect(values.userIdentityId, isNull);
    values.userIdentityId = 1;
    expect(values.userIdentityId, 1);
    values.userIdentityId = null;
    expect(values.userIdentityId, isNull);
  });
}
