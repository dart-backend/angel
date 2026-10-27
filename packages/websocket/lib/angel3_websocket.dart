/// WebSocket plugin for Angel.
library;

/// A notification from the server that something has occurred.
class WebSocketEvent<Data> {
  String? eventName;
  Data? data;

  WebSocketEvent({this.eventName, this.data});

  factory WebSocketEvent.fromJson(Map data) => WebSocketEvent(
    eventName: data['eventName']?.toString(),
    data: data['data'] as Data?,
  );

  WebSocketEvent<T> cast<T>() {
    if (T == Data) {
      return this as WebSocketEvent<T>;
    } else {
      return WebSocketEvent<T>(eventName: eventName, data: data as T?);
    }
  }

  Map<String, dynamic> toJson() {
    return {'eventName': eventName, 'data': data};
  }
}

/// A command sent to the server, usually corresponding to a service method.
class WebSocketAction {
  String? id;
  String? eventName;
  dynamic data;
  Map<String, dynamic> params;

  WebSocketAction({this.id, this.eventName, this.data, this.params = const {}});

  /// A missing `id` or `eventName` is `null`, and `params` that are not a
  /// map are none.
  factory WebSocketAction.fromJson(Map data) => WebSocketAction(
    id: data['id']?.toString(),
    eventName: data['eventName']?.toString(),
    data: data['data'],
    params: switch (data['params']) {
      Map params => {
        for (var MapEntry(:key, :value) in params.entries) '$key': value,
      },
      _ => {},
    },
  );

  Map<String, dynamic> toJson() {
    return {'id': id, 'eventName': eventName, 'data': data, 'params': params};
  }
}
