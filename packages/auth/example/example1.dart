import 'package:angel3_auth/angel3_auth.dart';
import 'package:angel3_container/mirrors.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:io/ansi.dart';
import 'package:logging/logging.dart';
import 'package:collection/collection.dart';

class User extends Model {
  String? username, password;

  User({this.username, this.password});

  static User parse(Map<String, dynamic> map) {
    return User(
      username: map['username'],
      password: map['password'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'password': password,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String()
    };
  }
}

/*
 * Backend for callback test cases
 */
void main() async {
  hierarchicalLoggingEnabled = true;

  Angel app = Angel(reflector: MirrorsReflector());
  AngelHttp angelHttp = AngelHttp(app);
  app.use('/users', MapService());

  var oldErrorHandler = app.errorHandler;
  app.errorHandler = (e, req, res) {
    app.logger.severe(e.message, e, e.stackTrace ?? StackTrace.current);
    return oldErrorHandler(e, req, res);
  };

  app.logger = Logger('angel3_auth')
    ..level = Level.FINEST
    ..onRecord.listen((rec) {
      print(rec);

      if (rec.error != null) {
        print(yellow.wrap(rec.error.toString()));
      }

      if (rec.stackTrace != null) {
        print(yellow.wrap(rec.stackTrace.toString()));
      }
    });

  await app
      .findService('users')
      ?.create({'username': 'jdoe1', 'password': 'password'});

  var auth = AngelAuth<User>(
      serializer: (u) => u.id ?? '',
      deserializer: (id) async =>
          await app.findService('users')?.read(id) as User);
  //auth.serializer = (u) => u.id;
  //auth.deserializer =
  //    (id) async => await app.findService('users')!.read(id) as User;

  await app.configure(auth.configureServer);

  auth.strategies['local'] = LocalAuthStrategy((username, password) async {
    var users = await app
        .findService('users')
        ?.index()
        .then((it) => it.map<User>((m) => User.parse(m)).toList());

    var result = users?.firstWhereOrNull(
        (user) => user.username == username && user.password == password);

    return Future.value(result);
  });

  app.post(
      '/login',
      auth.authenticate('local', AngelAuthOptions(callback: (req, res, token) {
        res
          ..write('Hello!')
          ..close();
      })));

  app.get('/', (req, res) => res.write("Hello"));

  app.chain([
    (req, res) {
      if (!req.container!.has<User>()) {
        req.container!.registerSingleton<User>(
            User(username: req.params['name']?.toString()));
      }
      return true;
    }
  ]).post(
    '/existing/:name',
    auth.authenticate('local'),
  );

  await angelHttp.startServer('127.0.0.1', 3000);
}
