import 'dart:convert';
import 'package:test/test.dart';
import 'common.dart';

void main() {
  var app = MockAngel();
  var todoService = app.service('api/todos');

  test('sets method,body,headers,path', () async {
    await app.post(Uri.parse('/post'),
        headers: {'method': 'post'}, body: 'post');
    expect((app.client as SpecClient).spec!.method, 'POST');
    expect((app.client as SpecClient).spec!.path, '/post');
    expect((app.client as SpecClient).spec!.headers['method'], 'post');
    expect(await read((app.client as SpecClient).spec!.request.finalize()),
        'post');
  });

  group('service methods', () {
    test('index', () async {
      await todoService.index();
      expect((app.client as SpecClient).spec!.method, 'GET');
      expect((app.client as SpecClient).spec!.path, '/api/todos');
    });

    test('read', () async {
      await todoService.read('sleep');
      expect((app.client as SpecClient).spec!.method, 'GET');
      expect((app.client as SpecClient).spec!.path, '/api/todos/sleep');
    });

    test('create', () async {
      await todoService.create({});
      expect((app.client as SpecClient).spec!.method, 'POST');
      expect((app.client as SpecClient).spec!.headers['content-type'],
          startsWith('application/json'));
      expect((app.client as SpecClient).spec!.path, '/api/todos');
      expect(await read((app.client as SpecClient).spec!.request.finalize()),
          '{}');
    });

    test('modify', () async {
      await todoService.modify('sleep', {});
      expect((app.client as SpecClient).spec!.method, 'PATCH');
      expect((app.client as SpecClient).spec!.headers['content-type'],
          startsWith('application/json'));
      expect((app.client as SpecClient).spec!.path, '/api/todos/sleep');
      expect(await read((app.client as SpecClient).spec!.request.finalize()),
          '{}');
    });

    test('update', () async {
      await todoService.update('sleep', {});
      expect((app.client as SpecClient).spec!.method, 'POST');
      expect((app.client as SpecClient).spec!.headers['content-type'],
          startsWith('application/json'));
      expect((app.client as SpecClient).spec!.path, '/api/todos/sleep');
      expect(await read((app.client as SpecClient).spec!.request.finalize()),
          '{}');
    });

    test('remove', () async {
      await todoService.remove('sleep');
      expect((app.client as SpecClient).spec!.method, 'DELETE');
      expect((app.client as SpecClient).spec!.path, '/api/todos/sleep');
    });
  });

  group('authentication', () {
    test('no type defaults to token', () async {
      await app.authenticate(credentials: '<jwt>');
      expect((app.client as SpecClient).spec!.path, '/auth/token');
    });

    test('sets type', () async {
      await app.authenticate(type: 'local');
      expect((app.client as SpecClient).spec!.path, '/auth/local');
    });

    test('credentials send right body', () async {
      await app
          .authenticate(type: 'local', credentials: {'username': 'password'});
      print((app.client as SpecClient).spec?.headers);
      expect(
        await read((app.client as SpecClient).spec!.request.finalize()),
        json.encode({'username': 'password'}),
      );
    });
  });
}
