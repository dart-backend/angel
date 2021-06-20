import 'package:user_agent/user_agent.dart';

void main() {
  var ua = UserAgent(
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/55.0.2883.95 Safari/537.36');
  print(ua.isChrome);
}
