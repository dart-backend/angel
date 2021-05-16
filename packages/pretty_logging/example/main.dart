import 'package:logging/logging.dart';
import 'package:angel3_pretty_logging/angel3_pretty_logging.dart';

void main() {
  Logger.root
    ..level = Level.ALL
    ..onRecord.listen(prettyLog)
    ..info('Hey!')
    ..finest('Bye!')
    ..severe('Oops!', StateError('Wrong!'), StackTrace.current);
}
