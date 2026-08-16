import 'package:angel3_oauth2/angel3_oauth2.dart';

void main() {
  var e = AuthorizationException(ErrorResponse('code', 'desc', 'state'));
  print(e.toJson());
  print(e.runtimeType);
}
