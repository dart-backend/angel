import 'package:angel3_file_service/angel3_file_service.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:file/local.dart';

void configureServer(Angel app) async {
  // Just like a normal service
  app.use(
    '/api/todos',
    JsonFileService(const LocalFileSystem().file('todos_db.json')),
  );
}
