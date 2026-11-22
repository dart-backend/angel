import 'package:angel3_route/angel3_route.dart';
import 'package:test/test.dart';

void main() {
  Router<String> routerOf() => Router<String>()
    ..get('/top', 'top').name = 'top'
    ..group('/api', (r) {
      r.get('/users/:id', 'user').name = 'user';
    });

  test('the routes of a group keep their names', () {
    var names = routerOf().routes.map((r) => r.name);
    expect(names, containsAll(['top', 'user']));
  });

  test('a flattened router keeps the names of its routes', () {
    var names = flatten(routerOf()).routes.map((r) => r.name);
    expect(names, containsAll(['top', 'user']));
  });

  test('navigate finds a route of a group by its name', () {
    expect(
      routerOf().navigate([
        'user',
        {'id': '7'},
      ]),
      '/api/users/7',
    );
  });
}
