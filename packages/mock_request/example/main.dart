import 'dart:async';
import 'package:angel3_mock_request/angel3_mock_request.dart';

Future<void> main() async {
  var rq = MockHttpRequest(
    'GET',
    Uri.parse('/foo'),
    persistentConnection: false,
  );
  await rq.close();
}
