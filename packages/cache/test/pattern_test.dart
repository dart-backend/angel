import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';

void main() {
  /*
  var filePat = Glob('**.txt');
  for (var entity in filePat.listSync()) {
    print(entity.path);
  }

  var result = filePat.allMatches(path);

  */

  var path = "ababa99.txt";
  //var regPat = RegExp('\w+\.txt');
  var regPat = RegExp('^/?\\w+\\.txt');
  var result = regPat.allMatches(path);

  print(result.length);
}
