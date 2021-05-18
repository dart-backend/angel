# angel3_pub_sub
[![version](https://img.shields.io/badge/pub-v3.0.2-brightgreen)](https://pub.dartlang.org/packages/angel3_pub_sub)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/angel_dart/discussion)](https://gitter.im/angel_dart/discussion)

[![License](https://img.shields.io/github/license/dukefirehawk/angel)](https://github.com/dukefirehawk/angel/tree/angel3/packages/pub_sub/LICENSE)

Keep application instances in sync with a simple pub/sub API.

# Installation
Add `angel3_pub_sub` as a dependency in your `pubspec.yaml` file:

```yaml
dependencies:
  angel3_pub_sub: ^3.0.0
```

Then, be sure to run `pub get` in your terminal.

# Usage
`pub_sub` is your typical pub/sub API. However, `angel3_pub_sub` enforces authentication of every
request. It is very possible that `angel3_pub_sub` will run on both servers and in the browser,
or on a platform angel3_pub_sublike Flutter. Thus, there are provisions available to limit
access.

**Be careful to not leak any `angel3_pub_sub` client ID's if operating over a network.**
If you do, you risk malicious users injecting events into your application, which
could ultimately spell *disaster*.

A `angel3_pub_sub` server can operate across multiple *adapters*, which take care of interfacing data over different
media. For example, a single server can handle pub/sub between multiple Isolates and TCP Sockets, as well as
WebSockets, simultaneously.

```dart
import 'package:angel3_pub_sub/angel3_pub_sub.dart' as pub_sub;

main() async {
  var server =  pub_sub.Server([
     FooAdapter(...),
     BarAdapter(...)
  ]);

  server.addAdapter( BazAdapter(...));

  // Call `start` to activate adapters, and begin handling requests.
  server.start();
}
```
### Trusted Clients
You can use `package:angel3_pub_sub` without explicitly registering
clients, *if and only if* those clients come from trusted sources.

Clients via `Isolate` are always trusted.

Clients via `package:json_rpc_2` must be explicitly marked
as trusted (i.e. using an IP whitelist mechanism):

```dart
JsonRpc2Adapter(..., isTrusted: false);

// Pass `null` as Client ID when trusted...
pub_sub.IsolateClient(null);
```

### Access Control
The ID's of all *untrusted* clients who will connect to the server must be known at start-up time.
You may not register new clients after the server has started. This is mostly a security consideration;
if it is impossible to register new clients, then malicious users cannot grant themselves additional
privileges within the system.

```dart
import 'package:angel3_pub_sub/angel3_pub_sub.dart' as pub_sub;

main() async {
  // ...
  server.registerClient(const ClientInfo('<client-id>'));

  // Create a user who can subscribe, but not publish.
  server.registerClient(const ClientInfo('<client-id>', canPublish: false));

  // Create a user who can publish, but not subscribe.
  server.registerClient(const ClientInfo('<client-id>', canSubscribe: false));

  // Create a user with no privileges whatsoever.
  server.registerClient(const ClientInfo('<client-id>', canPublish: false, canSubscribe: false));

  server.start();
}
```

## Isolates
If you are just running multiple instances of a server,
use `package:angel3_pub_sub/isolate.dart`. 

You'll need one isolate to be the master. Typically this is the first isolate you create.

```dart
import 'dart:io';
import 'dart:isolate';
import 'package:angel3_pub_sub/isolate.dart' as pub_sub;
import 'package:angel3_pub_sub/angel3_pub_sub.dart' as pub_sub;

void main() async {
  // Easily bring up a server.
  var adapter = pub_sub.IsolateAdapter();
  var server = pub_sub.Server([adapter]);

  // You then need to create a client that will connect to the adapter.
  // Each isolate in your application should contain a client.
  for (int i = 0; i < Platform.numberOfProcessors - 1; i++) {
    server.registerClient(pub_sub.ClientInfo('client$i'));
  }

  // Start the server.
  server.start();

  // Next, let's start isolates that interact with the server.
  //
  // Fortunately, we can send SendPorts over Isolates, so this is no hassle.
  for (int i = 0; i < Platform.numberOfProcessors - 1; i++)
    Isolate.spawn(isolateMain, [i, adapter.receivePort.sendPort]);

  // It's possible that you're running your application in the server isolate as well:
  isolateMain([0, adapter.receivePort.sendPort]);
}

void isolateMain(List args) {
  var client =
      pub_sub.IsolateClient('client${args[0]}', args[1] as SendPort);

  // The client will connect automatically. In the meantime, we can start subscribing to events.
  client.subscribe('user::logged_in').then((sub) {
    // The `ClientSubscription` class extends `Stream`. Hooray for asynchrony!
    sub.listen((msg) {
      print('Logged in: $msg');
    });
  });
}

```

## JSON RPC 2.0
If you are not running on isolates, you need to import
`package:angel3_pub_sub/json_rpc_2.dart`. This library leverages `package:json_rpc_2` and
`package:stream_channel` to create clients and servers that can hypothetically run on any
medium, i.e. WebSockets, or TCP Sockets.

Check out `test/json_rpc_2_test.dart` for an example of serving `angel3_pub_sub` over TCP sockets.

# Protocol
`angel3_pub_sub` is built upon a simple RPC, and this package includes
an implementation that runs via `SendPort`s and `ReceivePort`s, as
well as one that runs on any `StreamChannel<String>`.

Data sent over the wire looks like the following:

```typescript
// Sent by a client to initiate an exchange.
interface Request {
  // This is an arbitrary string, assigned by your client, but in every case,
  // the client uses this to match your requests with asynchronous responses.
  request_id: string,
  
  // The ID of the client to authenticate as.
  // 
  // As you can imagine, this should be kept secret, to prevent breaches.
  client_id: string,

  // Required for *every* request.
  params: {
    // A value to be `publish`ed.
    value?: any,

    // The name of an event to `publish`.
    event_name?: string,

    // The ID of a subscription to be cancelled.
    subscription_id?: string
  }
}

/// Sent by the server in response to a request.
interface Response {
  // `true` for success, `false` for failures.
  status: boolean,
  
  // Only appears if `status` is `false`; explains why an operation failed.
  error_message?: string,

  // Matches the request_id sent by the client.
  request_id: string,

  result?: {
    // The number of other clients to whom an event was `publish`ed.
    listeners:? number,

    // The ID of a created subscription.
    subscription_id?: string
  }
}
```

When sending via JSON_RPC 2.0, the `params` of a `Request` are simply folded into the object
itself, for simplicity's sake. In this case, a response will be sent as a notification whose
name is the `request_id`.

In the case of Isolate clients/servers, events will be simply sent as Lists:

```dart
['<event-name>', value]
```

Clients can send the following (3) methods:

* `subscribe` (`event_name`:string): Subscribe to an event.
* `unsubscribe` (`subscription_id`:string): Unsubscribe from an event you previously subscribed to.
* `publish` (`event_name`:string, `value`:any): Publish an event to all other clients who are subscribed.

The client and server in `package:angel3_pub_sub/isolate.dart` must make extra
provisions to keep track of client ID's. Since `SendPort`s and `ReceivePort`s
do not have any sort of guaranteed-unique ID's, new clients must send their
`SendPort` to the server before sending any requests. The server then responds
with an `id` that must be used to identify a `SendPort` to send a response to.