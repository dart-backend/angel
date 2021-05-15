import 'dart:async';
import 'dart:isolate';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_production/angel3_production.dart';
import 'package:angel3_pub_sub/angel3_pub_sub.dart' as pub_sub;

void main(List<String> args) => Runner('example', configureServer).run(args);

Future configureServer(Angel app) async {
  // Use the injected `pub_sub.Client` to send messages.
  var client = app.container!.make<pub_sub.Client>()!;
  String? greeting = 'Hello! This is the default greeting.';

  // We can listen for an event to perform some behavior.
  //
  // Here, we use message passing to synchronize some common state.
  var onGreetingChanged = await client.subscribe('greeting_changed');
  onGreetingChanged
      .cast<String>()
      .listen((newGreeting) => greeting = newGreeting);

  // Add some routes...
  app.get('/', (req, res) => 'Hello, production world!');

  app.get('/404', (req, res) {
    res.statusCode = 404;
    return res.close();
  });

  // Create some routes to demonstrate message passing.
  app.get('/greeting', (req, res) => greeting);

  // This route will push a new value for `greeting`.
  app.get('/change_greeting/:newGreeting', (req, res) {
    greeting = req.params['newGreeting'] as String?;
    client.publish('greeting_changed', greeting);
    return 'Changed greeting -> $greeting';
  });

  // The `Runner` helps with fault tolerance.
  app.get('/crash', (req, res) {
    // We'll crash this instance deliberately, but the Runner will auto-respawn for us.
    Timer(const Duration(seconds: 3), Isolate.current.kill);
    return 'Crashing in 3s...';
  });
}
