/// Various libraries useful for creating highly-extensible servers.
library;

import 'dart:async';
import 'dart:io';

import 'bind_secure.dart';

export 'angel_http.dart';
export 'headers.dart' show HttpHeadersValues;
export 'http_request_context.dart';
export 'http_response_context.dart';

/// Boots a shared server instance. Use this if launching multiple isolates.
Future<HttpServer> startShared(Object? address, int port) =>
    HttpServer.bind(address ?? '127.0.0.1', port, shared: true);

/// Boots a shared HTTPS server instance of [securityContext]. Use this if
/// launching multiple isolates.
///
/// [requestClientCertificate] and [requireClientCertificate] are as of
/// [AngelHttp.fromSecurityContext].
Future<HttpServer> Function(Object?, int) startSharedSecure(
  SecurityContext securityContext, {
  bool requestClientCertificate = false,
  bool requireClientCertificate = false,
}) {
  return (address, int port) => bindSecure(
    address ?? '127.0.0.1',
    port,
    securityContext,
    shared: true,
    requestClientCertificate: requestClientCertificate,
    requireClientCertificate: requireClientCertificate,
  );
}
