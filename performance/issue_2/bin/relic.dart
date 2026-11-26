/// The Relic app of issue 2, on Relic's native transport.
library;

import 'dart:io';

import 'package:relic/relic.dart';
import 'package:relic_native/relic_native.dart';

import 'env.dart';

Future<void> main() async {
  final app = RelicApp()
    ..get('/', (_) => Response.ok())
    ..post('/user', (_) => Response.ok())
    ..get('/user/:user', (Request request) {
      final user = request.rawPathParameters[#user]!;
      return Response.ok(body: Body.fromString(user));
    });

  await app.serveNative(
    address: InternetAddress.anyIPv4,
    port: port,
    noOfIsolates: isolateCount,
  );
  print('relic listening on $port with $isolateCount isolates');
}
