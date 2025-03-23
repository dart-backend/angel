import 'package:angel3_auth/angel3_auth.dart';
import 'package:angel3_client/io.dart' as c;
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

const Map<String, String> user = {'username': 'foo', 'password': 'bar'};
var localOpts = AngelAuthOptions<Map<String, String>>(canRespondWithJson: true);

void main() {
  late Angel app;
  late AngelHttp http;
  late c.Angel client;

  setUp(() async {
    app = Angel();
    http = AngelHttp(app, useZone: false);
    var auth = AngelAuth(
        serializer: (_) async => 'baz', deserializer: (_) async => user);

    auth.strategies['local'] = LocalAuthStrategy(
      (username, password) async {
        if (username == 'foo' && password == 'bar') {
          return user;
        }

        return {};
      },
    );

    app.post('/auth/local', auth.authenticate('local', localOpts));

    await app.configure(auth.configureServer);

    app.logger = Logger('auth_test')
      ..onRecord.listen((rec) {
        print(
            '${rec.time}: ${rec.level.name}: ${rec.loggerName}: ${rec.message}');
      });

    var server = await http.startServer();

    client = c.Rest('http://${server.address.address}:${server.port}');
  });

  tearDown(() {
    http.close();
    client.close();
  });

  test('auth event fires', () async {
    var localAuth = await client.authenticate(type: 'local', credentials: user);
    print('JWT: ${localAuth.token}');
    print('Data: ${localAuth.data}');

    expect(localAuth.data, user);
  });
}
