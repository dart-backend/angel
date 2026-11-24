import 'package:angel3_route/angel3_route.dart';
import 'package:test/test.dart';

void main() {
  test('links are of mount, group and chain, in order', () {
    var router = Router<String>();
    var api = Router<String>()..get('/todos', 'todos');
    router.get('/', 'home');
    router.mount('/api', api);
    router.group('/admin', (r) => r.get('/users', 'users'));
    var chained = router.chain(['auth'])..get('/me', 'me');

    var links = router.links;
    expect(links.map((l) => l.path), ['/api', '/admin', '/']);
    expect(links[0].router, same(api));
    expect(links[2].router, same(chained));
    // A chain links its router, but does not mount it.
    expect(router.mounted.values, isNot(contains(chained)));
    expect(router.links, isA<List<SymlinkRoute<String>>>());
  });
}
