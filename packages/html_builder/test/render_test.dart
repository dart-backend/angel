import 'package:html/parser.dart' as html5;
import 'package:angel3_html_builder/elements.dart';
import 'package:angel3_html_builder/angel3_html_builder.dart';
import 'package:test/test.dart';

void main() {
  test('pretty', () {
    var $dom = html(
      lang: 'en',
      c: [
        head(c: [
          title(c: [text('Hello, world!')])
        ]),
        body(
          p: {'unresolved': true},
          c: [
            h1(c: [text('Hello, world!')]),
            br(),
            hr(),
          ],
        )
      ],
    );

    var rendered = StringRenderer().render($dom);
    print(rendered);

    var $parsed = html5.parse(rendered);
    var $title = $parsed.querySelector('title')!;
    expect($title.text.trim(), 'Hello, world!');
    var $h1 = $parsed.querySelector('h1')!;
    expect($h1.text.trim(), 'Hello, world!');
  });
}
