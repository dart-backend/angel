import 'dart:io';
import 'package:io/ansi.dart';

void printSeparator(String title) {
  var b = StringBuffer('===' + title.toUpperCase());

  int columns = 80;
  if (stdout.hasTerminal) {
    columns = stdout.terminalColumns - 3;
  }
  for (var i = b.length; i < columns; i++) {
    b.write('=');
  }
  for (var i = 0; i < 3; i++) {
    print(magenta.wrap(b.toString()));
  }
}
