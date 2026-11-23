import 'package:angel3_container/angel3_container.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_openapi/angel3_openapi.dart';

part 'aot_controller.g.dart';

/// A controller of generated reflection data, without `dart:mirrors`.
@injectable
@Expose('/items')
class ItemController extends Controller {
  @Expose('/int:id')
  @OpenApiOperation(
    summary: 'Read an item',
    responses: {200: OpenApiResponse('The item')},
  )
  Map<String, dynamic> read(int id) => {'id': id};
}
