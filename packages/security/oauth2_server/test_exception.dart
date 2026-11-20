import 'package:angel3_oauth2_server/angel3_oauth2_server.dart';

void main() {
  var e = AuthorizationException(ErrorResponse('code', 'desc', 'state'));
  print(e.toJson());
  print(e.runtimeType);
}
