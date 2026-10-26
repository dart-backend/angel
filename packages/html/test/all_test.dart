import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_html/angel3_html.dart';
import 'package:angel3_test/angel3_test.dart';
import 'package:belatuk_html_builder/elements.dart';
import 'package:test/test.dart';

void main() {
  Angel app;
  late TestClient client;
  late bool laterHandlerRan;

  setUp(() async {
    app = Angel();

    app.fallback(renderHtml());

    app.get('/html', (req, res) {
      return html(
        c: [
          head(
            c: [
              title(c: [text('ok')]),
            ],
          ),
        ],
      );
    });

    app.get(
      '/strict',
      chain([
        renderHtml(
          enforceAcceptHeader: true,
          renderer: StringRenderer(pretty: false),
        ),
        (req, res) {
          return div(c: [text('strict')]);
        },
      ]),
    );
    laterHandlerRan = false;
    app.fallback((req, res) {
      laterHandlerRan = true;
      throw AngelHttpException.notFound();
    });
    client = await connectTo(app);
  });

  tearDown(() => client.close());

  test('later handlers do not run', () async {
    var response = await client.get(Uri.parse('/html'));
    expect(response, hasStatus(200));
    expect(laterHandlerRan, isFalse);
  });

  test('sends the charset', () async {
    var response = await client.get(Uri.parse('/html'));
    expect(response.headers['content-type'], 'text/html; charset=utf-8');
  });

  test('sets content type and body', () async {
    var response = await client.get(Uri.parse('/html'));
    print('Response: ${response.body}');

    expect(
      response,
      allOf(
        hasContentType('text/html; charset=utf-8'),
        hasBody('<!DOCTYPE html><html><head><title>ok</title></head></html>'),
      ),
    );
  });

  group('enforce accept header', () {
    test('sends if correct accept or wildcard', () async {
      var response = await client.get(
        Uri.parse('/strict'),
        headers: {'accept': '*/*'},
      );
      print('Response: ${response.body}');
      expect(
        response,
        allOf(
          hasContentType('text/html; charset=utf-8'),
          hasBody('<!DOCTYPE html><div>strict</div>'),
        ),
      );

      response = await client.get(
        Uri.parse('/strict'),
        headers: {'accept': 'text/html,application/json,text/xml'},
      );
      print('Response: ${response.body}');
      expect(
        response,
        allOf(
          hasContentType('text/html; charset=utf-8'),
          hasBody('<!DOCTYPE html><div>strict</div>'),
        ),
      );
    });

    test('sends without an accept header, which accepts any type', () async {
      var response = await client.get(Uri.parse('/strict'));
      expect(response, hasStatus(200));
    });

    test('throws if incorrect accept', () async {
      var response = await client.get(
        Uri.parse('/strict'),
        headers: {'accept': 'application/json,text/xml'},
      );
      print('Response: ${response.body}');
      expect(
        response,
        isAngelHttpException(statusCode: 406, message: '406 Not Acceptable'),
      );
    });
  });
}
