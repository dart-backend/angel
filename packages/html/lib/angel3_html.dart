import 'dart:async';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:belatuk_html_builder/belatuk_html_builder.dart';

/// Returns a [RequestMiddleware] that allows you to return `html_builder` [Node]s as responses.
///
/// You can provide a custom [renderer]. The default renders minified HTML5 pages.
///
/// Set [enforceAcceptHeader] to `true` to throw a `406 Not Acceptable` if the
/// client doesn't accept HTML responses. A request without an `Accept` header
/// accepts any type, as RFC 9110 says. The header is checked when a [Node] is
/// returned, as other responses of the route need not be HTML.
RequestHandler renderHtml({
  StringRenderer? renderer,
  bool enforceAcceptHeader = false,
}) {
  var r = renderer ?? StringRenderer(pretty: false, html5: true);

  return (RequestContext req, ResponseContext res) {
    var oldSerializer = res.serializer;

    res.serializer = (data) {
      if (data is! Node) return oldSerializer(data);

      if (enforceAcceptHeader && !req.accepts('text/html')) {
        throw AngelHttpException.notAcceptable();
      }

      // [ResponseContext.serialize] writes the page and closes the response,
      // which ends the request.
      res.headers['content-type'] = 'text/html; charset=utf-8';
      return r.render(data);
    };

    return Future<bool>.value(true);
  };
}
