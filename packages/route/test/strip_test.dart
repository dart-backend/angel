import 'package:angel3_route/string_util.dart';
import 'package:test/test.dart';

void main() {
  test('strip leading', () {
    var a = '///a';
    var b = stripStraySlashes(a);
    print('$a => $b');
    expect(b, 'a');
  });

  test('strip trailing', () {
    var a = 'a///';
    var b = stripStraySlashes(a);
    print('$a => $b');
    expect(b, 'a');
  });

  test('strip both', () {
    var a = '///a///';
    var b = stripStraySlashes(a);
    print('$a => $b');
    expect(b, 'a');
  });

  test('intermediate slashes preserved', () {
    var a = '///a///b//';
    var b = stripStraySlashes(a);
    print('$a => $b');
    expect(b, 'a///b');
  });

  test('only if starts with', () {
    var a = 'd///a///b//';
    var b = stripStraySlashes(a);
    print('$a => $b');
    expect(b, 'd///a///b');
  });

  test('only if ends with', () {
    var a = '///a///b//c';
    var b = stripStraySlashes(a);
    print('$a => $b');
    expect(b, 'a///b//c');
  });

  test('empty and only slashes', () {
    expect(stripStraySlashes(''), '');
    expect(stripStraySlashes('/'), '');
    expect(stripStraySlashes('///'), '');
  });

  test('no slashes to strip gives the same string', () {
    var a = 'a/b';
    expect(identical(stripStraySlashes(a), a), isTrue);
  });

  test('matches the RegExp it replaces', () {
    var rgx = RegExp(r'(^/+)|(/+$)');
    var parts = ['', '/', '//', 'a', 'b', 'ab'];
    for (var a in parts) {
      for (var b in parts) {
        for (var c in parts) {
          var s = '$a$b$c';
          expect(stripStraySlashes(s), s.replaceAll(rgx, ''), reason: s);
          expect(stripStray(s, '/'), s.replaceAll(rgx, ''), reason: s);
        }
      }
    }
  });

  test('stripStray with a longer needle', () {
    expect(stripStray('ababxab', 'ab'), 'x');
    expect(stripStray('abab', 'ab'), '');
    expect(stripStray('aba', 'ab'), 'a');
    expect(stripStray('x', ''), 'x');
    expect(stripRegexStraySlashes(r'\/\/a\/b\/'), r'a\/b');
    expect(stripRegexStraySlashes(r'\a/'), r'\a/');
  });
}
