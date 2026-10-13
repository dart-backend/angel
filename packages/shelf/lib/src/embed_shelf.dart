import 'package:angel3_framework/angel3_framework.dart';
import 'package:shelf/shelf.dart' as shelf;

import 'convert.dart';

/// Simply passes an incoming request to a `shelf` handler.
///
/// [throwOnNullResponse] has no effect: a [shelf.Handler] always returns a
/// [shelf.Response], so there is never a `null` response to throw on.
RequestHandler embedShelf(
  shelf.Handler handler, {
  String? handlerPath,
  Map<String, Object>? context,
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
      // On hijack, do nothing, because the hijack handlers already call res.detach();
      return null;
    } catch (e) {
      rethrow;
    }
  };
}
