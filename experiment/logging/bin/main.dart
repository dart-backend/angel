import 'dart:isolate';

Future<void> runApp(var message) async {
  var stopwatch = Stopwatch()..start();

  // Do something

  print('Execution($message) Time: ${stopwatch.elapsed.inMilliseconds}ms');
  stopwatch.stop();
}

void main() async {
  var concurrency = 6000;

  for (var i = 0; i < concurrency; i++) {
    Isolate.spawn(runApp, 'Instance_$i');
  }

  await Future.delayed(const Duration(seconds: 10));

  //print("Exit");
}
