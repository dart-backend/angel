import 'dart:async';
import 'dart:io';

import 'package:angel3_framework/angel3_framework.dart' hide Header;
import 'package:angel3_framework/http2.dart';
import 'package:http2/transport.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

void main() {
  test('a request that cannot be read does not hold back its body', () async {
    var stream = _FakeStream();
    var req = Http2RequestContext.from(
      stream,
      _FakeSocket(),
      Angel(),
      {},
      const Uuid(),
    );
    // No :path, so the request fails once the body starts.
    stream.messages
      ..add(HeadersStreamMessage([Header.ascii(':method', 'POST')]))
      ..add(DataStreamMessage([1]));
    await expectLater(req, throwsA(isA<AngelHttpException>()));

    stream.messages.add(DataStreamMessage([2]));
    await pumpEventQueue();
    // A paused stream would never be read again, stalling its flow control.
    expect(stream.messages.isPaused, isFalse);
  });
}

class _FakeStream implements ServerTransportStream {
  final messages = StreamController<StreamMessage>();

  @override
  Stream<StreamMessage> get incomingMessages => messages.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSocket implements Socket {
  @override
  InternetAddress get address => InternetAddress.loopbackIPv4;

  @override
  int get port => 443;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
