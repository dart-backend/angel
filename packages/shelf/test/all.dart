import 'package:test/test.dart';

import 'embed_shelf_test.dart' as embed_shelf;
import 'shelf_request_test.dart' as shelf_request;

void main() {
  group('embed_shelf', embed_shelf.main);
  group('shelf_request', shelf_request.main);
}
