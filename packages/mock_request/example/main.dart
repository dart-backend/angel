import 'dart:async';
import 'package:mock_request/mock_request.dart';

Future<void> main() async {
  var rq = MockHttpRequest('GET', Uri.parse('/foo'));
  await rq.close();
}
