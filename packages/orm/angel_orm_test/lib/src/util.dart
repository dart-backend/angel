import 'dart:io';
import 'package:io/ansi.dart';

void printSeparator(String title) {
  var b = StringBuffer('===' + title.toUpperCase());
  for (var i = b.length; i < stdout.terminalColumns - 3; i++) {
    b.write('=');
  }
  for (var i = 0; i < 3; i++) {
    print(magenta.wrap(b.toString()));
  }
}
