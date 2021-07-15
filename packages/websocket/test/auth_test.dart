import 'package:angel3_auth/angel3_auth.dart';
import 'package:angel3_client/io.dart' as c;
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_websocket/io.dart' as c;
import 'package:angel3_websocket/server.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

const Map<String, String> USER = {'username': 'foo', 'password': 'bar'};

void main() {
  Angel app;
  late AngelHttp http;
  late c.Angel client;
  late c.WebSockets ws;

  setUp(() async {
    app = Angel();
    http = AngelHttp(app, useZone: false);
    var auth = AngelAuth(
        serializer: (_) async => 'baz', deserializer: (_) async => USER);

    auth.strategies['local'] = LocalAuthStrategy(
      (username, password) async {
        if (username == 'foo' && password == 'bar') {
          return USER;
        }
      },
    );

    app.post('/auth/local', auth.authenticate('local'));

    await app.configure(auth.configureServer);
    var sock = AngelWebSocket(app);

    await app.configure(sock.configureServer);

    app.all('/ws', sock.handleRequest);
    app.logger = Logger('angel_auth')..onRecord.listen(print);

    var server = await http.startServer();

    client = c.Rest('http://${server.address.address}:${server.port}');

    ws = c.WebSockets('ws://${server.address.address}:${server.port}/ws');
    await ws.connect();
  });

  tearDown(() {
    http.close();
    client.close();
    ws.close();
  });

  test('auth event fires', () async {
    var localAuth = await client.authenticate(type: 'local', credentials: USER);
    print('JWT: ${localAuth.token}');

    ws.authenticateViaJwt(localAuth.token);
    var auth = await ws.onAuthenticated.first;
    expect(auth.token, localAuth.token);
  });
}
