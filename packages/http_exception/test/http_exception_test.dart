import 'package:angel3_http_exception/angel3_http_exception.dart';
import 'package:test/test.dart';

void main() {
  group('fromMap', () {
    test('accepts a status code as text or a double', () {
      expect(
        AngelHttpException.fromMap({'status_code': '404'}).statusCode,
        404,
      );
      expect(
        AngelHttpException.fromMap({'status_code': 404.0}).statusCode,
        404,
      );
      expect(AngelHttpException.fromMap({'statusCode': 403}).statusCode, 403);
      expect(AngelHttpException.fromMap({'status_code': 'x'}).statusCode, 500);
    });

    test('falls back to 500 for anything that is not a status code', () {
      for (var bad in [
        double.nan,
        double.infinity,
        404.9,
        '0x194',
        '-1',
        '99999',
        99,
        600,
        true,
      ]) {
        expect(
          AngelHttpException.fromMap({'status_code': bad}).statusCode,
          500,
          reason: '$bad',
        );
      }
    });

    test('tries statusCode when status_code is not valid', () {
      expect(
        AngelHttpException.fromMap({'status_code': 'abc', 'statusCode': 404})
            .statusCode,
        404,
      );
    });

    test('uses fallbackStatusCode when there is no valid status code', () {
      expect(
        AngelHttpException.fromMap({}, fallbackStatusCode: 404).statusCode,
        404,
      );
      expect(
        AngelHttpException.fromMap({
          'status_code': 403,
        }, fallbackStatusCode: 404).statusCode,
        403,
      );
    });

    test('defaults to the same message as the constructor', () {
      expect(
        AngelHttpException.fromMap({}).message,
        AngelHttpException().message,
      );
    });
  });

  test('fromJson throws FormatException for JSON that is not an object', () {
    expect(
      () => AngelHttpException.fromJson('["oops"]'),
      throwsFormatException,
    );
    expect(() => AngelHttpException.fromJson('null'), throwsFormatException);
  });

  test('toJson returns a copy of errors', () {
    var e = AngelHttpException.badRequest(errors: ['a']);
    (e.toJson()['errors'] as List).add('b');
    expect(e.errors, ['a']);
  });
}
