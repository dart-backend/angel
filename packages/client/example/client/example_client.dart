import 'package:angel3_client/io.dart' as c;

void main() async {
  c.Angel client = c.Rest('http://localhost:3000');

  const Map<String, String> user = {'username': 'foo', 'password': 'bar'};

  var localAuth = await client.authenticate(type: 'local', credentials: user);
  print('JWT: ${localAuth.token}');
  print('Data: ${localAuth.data}');
}
