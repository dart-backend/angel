import 'package:angel3_route/angel3_route.dart';
import 'package:test/test.dart';

void main() {
  test('resolve / on /', () {
    var router = Router()
      ..group('/', (router) {
        router.group('/', (router) {
          router.get('/', 'ok');
        });
      });

    expect(router.resolveAbsolute('/'), isNotNull);
  });
}
