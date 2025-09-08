import 'dart:js_interop';

import 'package:angel3_route/browser.dart';
import 'package:web/web.dart';

void basic(BrowserRouter router) {
  final $h1 = window.document.querySelector('h1');
  final $ul = window.document.getElementById('handlers');

  router.onResolve.listen((result) {
    final route = result.route;

    if ($h1 != null && $ul != null) {
      $h1.textContent = 'Active Route: ${route.name}';

      // TODO: Relook at this logic
      var ulList = $ul.children;
      for (var i = ulList.length; i > 0; i--) {
        ulList.item(i - 1)?.remove();
      }

      var newList = result.allHandlers.map(
        (handler) => HTMLLIElement()..textContent = handler.toString(),
      );

      for (var rec in newList) {
        $ul.add(rec);
      }

      // With dart:html
      //$ul.children
      //  ..clear()
      //  ..addAll(result.allHandlers.map(
      //      (handler) => HTMLLIElement()..textContent = handler.toString()));
    } else {
      print('No active Route');
    }
    //}
  });

  router.get('a', 'a handler');

  router.group('b', (router) {
    router.get('a', 'b/a handler').name = 'b/a';
    router.get('b', 'b/b handler', middleware: ['b/b middleware']).name = 'b/b';
  }, middleware: ['b middleware']);

  router.get('c', 'c handler');

  router
    ..dumpTree()
    ..listen();
}
