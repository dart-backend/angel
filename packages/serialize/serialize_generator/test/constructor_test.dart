import 'package:test/test.dart';

import 'models/account.dart';

/// A model whose class has a constructor of its own (issue 171).
void main() {
  var account = Account('eu', owner: 'ana', tier: 2, note: 'vip', email: 'a@x');

  test('passes the parameters to the constructor of the model', () {
    expect(account.region, 'eu');
    expect(account.level, 20);
    expect(account.owner, 'ana');
    expect(account.note, 'vip');
    expect(account.email, 'a@x');
  });

  test('uses the default of a named parameter of no field', () {
    expect(Account('eu', owner: 'ana').level, 10);
  });

  test('copyWith keeps the fields not given', () {
    var copy = account.copyWith('us', owner: 'bo');
    expect(copy.region, 'us');
    expect(copy.owner, 'bo');
    expect(copy.note, 'vip');
    expect(copy.email, 'a@x');
    expect(copy.level, 10);
  });

  test('round-trips through toMap and fromMap', () {
    var map = AccountSerializer.toMap(account);
    expect(map, {'owner': 'ana', 'note': 'vip', 'email': 'a@x'});
    var read = AccountSerializer.fromMap(map, 'eu', tier: 3);
    expect(read.region, 'eu');
    expect(read.level, 30);
    expect(read, account);
  });
}
