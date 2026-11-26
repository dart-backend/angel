import 'package:angel3_framework/angel3_framework.dart';
import 'package:shelf/shelf.dart' as shelf;

import 'convert.dart';
import 'hijack.dart';

/// Simply passes an incoming request to a `shelf` handler.
///
/// [throwOnNullResponse] has no effect: a [shelf.Handler] always returns a
/// [shelf.Response], so there is never a `null` response to throw on.
RequestHandler embedShelf(
  shelf.Handler handler, {
  String? handlerPath,
  Map<String, Object>? context,
  @Deprecated('Has no effect, as a shelf.Handler cannot return null.')
  bool throwOnNullResponse = false,
}) {
  return (RequestContext req, ResponseContext res) async {
    var shelfRequest = await convertRequest(
      req,
      res,
      handlerPath: handlerPath,
      context: context,
    );
    try {
      var result = await handler(shelfRequest);
      await mergeShelfResponse(result, res);
      return false;
    } on shelf.HijackException {
      // The hijack runs in a microtask, and detaches the response; wait for
      // it, or the response would be sent before the handler has the
      // connection.
      await hijackOf(shelfRequest);
      return null;
    }
  };
}
