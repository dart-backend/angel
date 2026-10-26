import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_validate/server.dart';
import 'package:test/test.dart';

void main() {
  late Angel app;

  setUp(() => app = Angel());

  final isPositiveId = predicateWithAngel(
    (key, value, app) => value is int && value > 0,
    'a positive id',
  );

  test('an AngelMatcher does not match null', () async {
    var validator = Validator({'userId': isPositiveId});
    var result = await asyncApplyValidator(validator, {'userId': null}, app);
    expect(result.errors, ["'userId': expected a positive id"]);
  });

  test('an AngelMatcher uses the custom error message', () async {
    var validator = Validator(
      {'userId': isPositiveId},
      customErrorMessages: {'userId': 'No user {{value}}'},
    );
    var result = await asyncApplyValidator(validator, {'userId': -1}, app);
    expect(result.errors, ['No user -1']);
  });

  test('the AngelMatchers of a nested Validator run', () async {
    var validator = Validator({
      'owner': Validator({'userId': isPositiveId}),
    });

    var result = await asyncApplyValidator(validator, {
      'owner': {'userId': -1},
    }, app);
    expect(result.errors, ["'userId': expected a positive id"]);

    result = await asyncApplyValidator(validator, {
      'owner': {'userId': 1},
    }, app);
    expect(result.errors, isEmpty);
    expect(result.data, {
      'owner': {'userId': 1},
    });
  });

  test('an AngelMatcher without an app throws, whatever the input', () async {
    var validator = Validator({'userId?': isPositiveId});
    expect(
      asyncApplyValidator(validator, {'userId': 1}, null),
      throwsStateError,
    );
    expect(asyncApplyValidator(validator, {}, null), throwsStateError);
  });

  test('a nested Validator sees keys without rules', () async {
    var validator = Validator({
      'account': Validator({'password': isConfirmed, 'userId': isPositiveId}),
    });
    var result = await asyncApplyValidator(validator, {
      'account': {'password': 'x', 'password_confirmed': 'x', 'userId': 1},
    }, app);
    expect(result.errors, isEmpty);
    expect(result.data, {
      'account': {'password': 'x', 'userId': 1},
    });
  });

  test('an AngelMatcher is given the input as its context', () async {
    var validator = Validator({
      'token': matchWithAngel(
        (item, context, app) => equals(context['token_confirm']),
      ),
    });
    var result = await asyncApplyValidator(validator, {
      'token': 'a',
      'token_confirm': 'a',
    }, app);
    expect(result.errors, isEmpty);
    expect(result.data, {'token': 'a'});
  });

  test('a validator without AngelMatchers needs no app', () async {
    var validator = Validator({'name': isString});
    var result = await asyncApplyValidator(validator, {
      'name': 'a',
      'other': 1,
    }, null);
    expect(result.data, {'name': 'a'});
  });

  test('validateEvent refuses data that is not a Map', () async {
    var service = app.use('/todos', MapService());
    service.beforeRead.listen(validateEvent(Validator({'name': isString})));
    expect(
      service.read('1'),
      throwsA(
        isA<AngelHttpException>().having((e) => e.statusCode, 'status', 400),
      ),
    );
  });

  test('nested Validators filter their data', () {
    var validator = Validator({
      'address': Validator(
        {'zip*': isString},
        defaultValues: {'country': 'US'},
      ),
    });
    var result = validator.check({
      'address': {'zip': '1', 'evil': 'x'},
    });
    expect(result.errors, isEmpty);
    expect(result.data, {
      'address': {'zip': '1'},
    });
  });

  test('several nested Validators of a key keep the data of each', () {
    var validator = Validator({
      'address': [
        Validator({'zip': isString}),
        Validator({'city': isString}),
      ],
    });
    var result = validator.check({
      'address': {'zip': '1', 'city': 'A', 'evil': 'x'},
    });
    expect(result.errors, isEmpty);
    expect(result.data, {
      'address': {'zip': '1', 'city': 'A'},
    });
  });
}
