import 'dart:async';

import 'package:file/file.dart';
import 'package:jael3/jael3.dart' as jael;
import 'package:jael3_preprocessor/jael3_preprocessor.dart' as jael;

Future<jael.Document?> process(
    jael.Document doc, Directory dir, errorHandler(jael.JaelError e)) {
  return jael.resolve(doc, dir, onError: errorHandler, patch: [
    (doc, dir, onError) {
      print(doc!.root.children.length);
      return doc;
    },
  ]);
}
