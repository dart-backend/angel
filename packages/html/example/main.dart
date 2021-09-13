import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_framework/http.dart';
import 'package:angel3_html/angel3_html.dart';
import 'package:belatuk_html_builder/elements.dart';
import 'package:logging/logging.dart';

void main() async {
  var app = Angel();
  var http = AngelHttp(app);
  app.logger = Logger('angel_html')
    ..onRecord.listen((rec) {
      print(rec);
      if (rec.error != null) print(rec.error);
      if (rec.stackTrace != null) print(rec.stackTrace);
    });

  app.fallback(renderHtml());

  app.get('/html', (req, res) {
    return html(c: [
      head(c: [
        title(c: [text('ok')])
      ])
    ]);
  });

  app.get(
    '/strict',
    chain([
      renderHtml(
        enforceAcceptHeader: true,
        renderer: StringRenderer(
          //doctype: null,
          pretty: false,
        ),
      ),
      (req, res) {
        return div(c: [text('strict')]);
      },
    ]),
  );

  app.fallback((req, res) => throw AngelHttpException.notFound());

  await http.startServer('127.0.0.1', 3000);
  print('Listening at ${http.uri}');
}
