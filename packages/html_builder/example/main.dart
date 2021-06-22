import 'package:angel3_html_builder/elements.dart';

void main() {
  var dom = html(lang: 'en', c: [
    head(c: [
      title(c: [text('Hello, world!')])
    ]),
    body(c: [
      h1(c: [text('Hello, world!')]),
      p(c: [text('Ok')])
    ])
  ]);

  print(dom);
}
