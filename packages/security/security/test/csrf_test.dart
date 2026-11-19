import 'dart:convert';
import 'dart:io';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_security/angel3_security.dart';
import 'package:angel3_test/angel3_test.dart';
import 'package:test/test.dart';

void main() {
  const origin = 'https://example.com';
  var signer = CookieSigner.fromStringKey('a key from the configuration');
  late TestClient client;

  Future<void> serve(CsrfFilter csrf) async {
    var app = Angel()
      ..fallback(csrf.handleRequest)
      ..get('/form', (req, res) => req.container!.make<CsrfToken>().value)
      ..post('/change', (req, res) => 'changed');
    client = await connectTo(app);
  }

  setUp(() => serve(CsrfFilter(signer, allowedOrigins: {origin})));
  tearDown(() => client.close());

  /// Gets a token, and keeps its cookie in the client, if one was sent.
  Future<String> getToken() async {
    var response = await client.get(Uri.parse('/form'));
    var header = response.headers['set-cookie'];
    if (header != null) {
      var cookie = Cookie.fromSetCookieValue(header);
      client.cookies
        ..removeWhere((c) => c.name == cookie.name)
        ..add(cookie);
    }
    return response.body.replaceAll('"', '');
  }

  Future<int> post(Map<String, String> headers, [Map<String, String>? body]) =>
      client
          .post(Uri.parse('/change'), headers: headers, body: body)
          .then((r) => r.statusCode);

  test('issues a signed, script-readable, SameSite cookie', () async {
    var response = await client.get(Uri.parse('/form'));
    expect(response.statusCode, 200);
    var cookie = Cookie.fromSetCookieValue(response.headers['set-cookie']!);
    expect(cookie.name, 'XSRF-TOKEN');
    expect(cookie.httpOnly, isFalse);
    expect(cookie.secure, isTrue);
    expect(cookie.sameSite, SameSite.lax);
    expect(signer.verify(cookie), isTrue);
  });

  test('keeps the token of a valid cookie', () async {
    var token = await getToken();
    expect(await getToken(), token);
  });

  test('accepts the token in the header, from the same origin', () async {
    var token = await getToken();
    expect(
      await post({'sec-fetch-site': 'same-origin', 'x-xsrf-token': token}),
      200,
    );
  });

  test('accepts the token in a form field, from an allowed Origin', () async {
    var token = await getToken();
    expect(await post({'origin': origin}, {'_csrf': token}), 200);
  });

  test('accepts an allowed Referer when there is no Origin', () async {
    var token = await getToken();
    expect(await post({'referer': '$origin/page', 'x-xsrf-token': token}), 200);
  });

  test('refuses a missing or wrong token', () async {
    var token = await getToken();
    expect(await post({'sec-fetch-site': 'same-origin'}), 403);
    expect(
      await post({
        'sec-fetch-site': 'same-origin',
        'x-xsrf-token': '${token}x',
      }),
      403,
    );
  });

  test('refuses another site, even with the token', () async {
    var token = await getToken();
    expect(
      await post({'sec-fetch-site': 'cross-site', 'x-xsrf-token': token}),
      403,
    );
    expect(
      await post({'origin': 'https://evil.com', 'x-xsrf-token': token}),
      403,
    );
    // Neither Sec-Fetch-Site, Origin nor Referer.
    expect(await post({'x-xsrf-token': token}), 403);
  });

  test('accepts the cookie value sent back, as axios does', () async {
    await getToken();
    var cookie = client.cookies.singleWhere((c) => c.name == 'XSRF-TOKEN');
    expect(
      await post({
        'sec-fetch-site': 'same-origin',
        'x-xsrf-token': cookie.value,
      }),
      200,
    );
  });

  test('accepts a same-site request from an allowed origin', () async {
    var token = await getToken();
    expect(
      await post({
        'sec-fetch-site': 'same-site',
        'origin': origin,
        'x-xsrf-token': token,
      }),
      200,
    );
    expect(
      await post({
        'sec-fetch-site': 'same-site',
        'origin': 'https://other.example.com',
        'x-xsrf-token': token,
      }),
      403,
    );
  });

  test('reads the field after an empty token header', () async {
    var token = await getToken();
    expect(
      await post(
        {'sec-fetch-site': 'same-origin', 'x-xsrf-token': ''},
        {'_csrf': token},
      ),
      200,
    );
  });

  test('a body that cannot be parsed fails with its own error', () async {
    await getToken();
    var response = await client.post(
      Uri.parse('/change'),
      headers: {
        'sec-fetch-site': 'same-origin',
        'content-type': 'application/json',
      },
      body: '{not json',
    );
    expect(response.statusCode, 400);
  });

  test('running twice on a request issues one token', () async {
    await client.close();
    var csrf = CsrfFilter(signer, allowedOrigins: {origin});
    var app = Angel()
      ..fallback(csrf.handleRequest)
      ..fallback(csrf.handleRequest)
      ..get('/form', (req, res) => req.container!.make<CsrfToken>().value)
      ..post('/change', (req, res) => 'changed');
    client = await connectTo(app);

    var response = await client.get(Uri.parse('/form'));
    var header = response.headers['set-cookie']!;
    expect('XSRF-TOKEN='.allMatches(header), hasLength(1));
    var cookie = Cookie.fromSetCookieValue(header);
    expect(response.body.replaceAll('"', ''), cookie.value);

    client.cookies.add(cookie);
    expect(
      await post({
        'sec-fetch-site': 'same-origin',
        'x-xsrf-token': cookie.value,
      }),
      200,
    );
  });

  test('the cookie does not tell the session id', () async {
    var token = await getToken();
    // The mock session of TestClient.
    const sessionId = 'mock-http-session';
    expect(token, isNot(contains(sessionId)));
    expect(
      token,
      isNot(
        contains(base64Url.encode(utf8.encode(sessionId)).replaceAll('=', '')),
      ),
    );
  });

  test('refuses a cookie that is not signed', () async {
    client.cookies.add(Cookie('XSRF-TOKEN', 'bW9jay1odHRwLXNlc3Npb24!forged'));
    expect(
      await post({'sec-fetch-site': 'same-origin', 'x-xsrf-token': 'forged'}),
      403,
    );
  });

  test('refuses a token bound to another session', () async {
    await client.close();
    await serve(
      CsrfFilter(
        signer,
        allowedOrigins: {origin},
        sessionKey: (req) => req.headers?.value('x-user'),
      ),
    );
    var response = await client.get(
      Uri.parse('/form'),
      headers: {'x-user': 'alice'},
    );
    client.cookies.add(
      Cookie.fromSetCookieValue(response.headers['set-cookie']!),
    );
    var token = response.body.replaceAll('"', '');
    var headers = {'sec-fetch-site': 'same-origin', 'x-xsrf-token': token};
    expect(await post({...headers, 'x-user': 'alice'}), 200);
    expect(await post({...headers, 'x-user': 'mallory'}), 403);
  });

  test('skips the requests it is told to', () async {
    await client.close();
    await serve(
      CsrfFilter(
        signer,
        allowedOrigins: {origin},
        skip: (req) =>
            req.headers?.value('authorization')?.startsWith('Bearer ') == true,
      ),
    );
    expect(await post({'authorization': 'Bearer abc'}), 200);
    expect(await post({}), 403);
  });
}
