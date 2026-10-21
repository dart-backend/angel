import 'package:angel3_framework/angel3_framework.dart';
import 'package:test/test.dart';

void main() {
  for (var hostname in ['api^example.com', 'a[b].com', r'a\b.com']) {
    test('rejects $hostname', () {
      expect(
        () => HostnameSyntaxParser(hostname).parse(),
        throwsFormatException,
      );
    });
  }

  test('accepts `-` and `_` in labels', () {
    var regExp = HostnameSyntaxParser('my-api_v2.example.com').parse();
    expect(regExp.hasMatch('my-api_v2.example.com'), isTrue);
  });
}
