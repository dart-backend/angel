import 'package:angel3_auth/angel3_auth.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:logging/logging.dart';

void main() async {
  const Map<String, String> user = {'username': 'foo', 'password': 'bar'};
  var localOpts =
      AngelAuthOptions<Map<String, String>>(canRespondWithJson: true);

  Angel app = Angel();
  AngelHttp http = AngelHttp(app, useZone: false);
  var auth = AngelAuth(
      serializer: (_) async => 'baz', deserializer: (_) async => user);

  auth.strategies['local'] = LocalAuthStrategy((username, password) async {
    if (username == 'foo' && password == 'bar') {
      return user;
    }

    return {};
  }, allowBasic: false);

  app.post('/auth/local', auth.authenticate('local', localOpts));

  await app.configure(auth.configureServer);

  app.logger = Logger('auth_test')
    ..onRecord.listen((rec) {
      print(
          '${rec.time}: ${rec.level.name}: ${rec.loggerName}: ${rec.message}');
    });

  await http.startServer('127.0.0.1', 3000);
}
