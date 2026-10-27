/// Not exported: waiting for a server's connections to close.
library;

import 'dart:io' show HttpServer;

/// Completes once [server] has no connections left, polling it, as
/// `dart:io` tells of no change. It stops once [server] is closed by force,
/// which `Driver.drain` does after its timeout.
Future<void> allConnectionsClosed(HttpServer server) async {
  while (server.connectionsInfo().total > 0) {
    await Future.delayed(const Duration(milliseconds: 10));
  }
}
