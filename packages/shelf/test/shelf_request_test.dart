import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_shelf/angel3_shelf.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:test/test.dart';

void main() {
  test('a malformed content-length is dropped, not thrown', () {
    var app = Angel();
    var rq = ShelfRequestContext(
      app,
      app.container.createChild(),
      shelf.Request(
        'POST',
        Uri.parse('http://localhost/'),
        headers: {'content-length': 'abc', 'x-foo': 'bar'},
      ),
      '/',
    );
    expect(rq.headers.contentLength, -1);
    expect(rq.headers.value('x-foo'), 'bar');
  });
}
