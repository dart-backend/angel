import 'dart:io';
import 'package:angel3_hot/angel3_hot.dart';
import 'server.dart';

void main() async {
  var hot = HotReloader(createServer, [
    Directory('src'),
    'server.dart',
    // Also allowed: Platform.script,
    Uri.parse('package:angel3_hot/angel3_hot.dart'),
  ]);
  await hot.startServer('127.0.0.1', 3000);
}
