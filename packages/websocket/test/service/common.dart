import 'dart:async';

import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_model/angel3_model.dart';
import 'package:angel3_websocket/base_websocket_client.dart';
import 'package:angel3_websocket/server.dart';
import 'package:test/test.dart';

class Todo extends Model {
  String? text;
  String? when;

  Todo({this.text, this.when});
}

class TodoService extends MapService {
  TodoService() : super() {
    configuration['ws:filter'] =
        (HookedServiceEvent e, WebSocketContext socket) {
      print('Hello, service filter world!');
      return true;
    };
  }
}

dynamic testIndex(BaseWebSocketClient client) async {
  var todoService = client.service('api/todos');
  scheduleMicrotask(() => todoService.index());

  var indexed = await todoService.onIndexed.first;
  print('indexed: $indexed');

  expect(indexed, isList);
  expect(indexed, isEmpty);
}
