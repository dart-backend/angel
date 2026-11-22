import 'dart:convert';
import 'dart:io' show X509Certificate;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'server.dart';

/// The certificate that a client presented in a TLS handshake (mutual TLS,
/// RFC 8705), which [AuthorizationServer.clientCertificateOf] gives of a
/// request.
///
/// It is of the TLS connection of the request, as of
/// `RequestContext.clientCertificate`, or of a header of a reverse proxy
/// that terminated TLS, of [ClientCertificate.fromPem].
class ClientCertificate {
  /// The certificate, DER-encoded.
  final Uint8List der;

  /// The subject of the certificate, as `X509Certificate.subject` gives it,
  /// such as `/CN=client/O=Example`, if known: `null` of a certificate of
  /// [ClientCertificate.fromPem], whose subject `dart:io` cannot read.
  final String? subject;

  /// A certificate of its DER encoding, [der].
  ClientCertificate(List<int> der, {this.subject})
    : der = Uint8List.fromList(der);

  /// The certificate of a TLS connection, of `dart:io`.
  factory ClientCertificate.ofX509(X509Certificate certificate) =>
      ClientCertificate(certificate.der, subject: certificate.subject);

  /// The certificate of [pem], a PEM `CERTIFICATE`, as a reverse proxy
  /// forwards it, once URL-decoded, as of nginx's
  /// `$ssl_client_escaped_cert`. Throws a [FormatException] if [pem] has
  /// none.
  factory ClientCertificate.fromPem(String pem) {
    var match = _pem.firstMatch(pem);
    if (match == null) {
      throw FormatException('No PEM "CERTIFICATE" is given.', pem);
    }
    var base64Text = match.group(1)!.replaceAll(RegExp(r'\s'), '');
    return ClientCertificate(base64.decode(base64Text));
  }

  static final RegExp _pem = RegExp(
    r'-----BEGIN CERTIFICATE-----([A-Za-z0-9+/=\s]+)-----END CERTIFICATE-----',
  );

  /// The SHA-256 thumbprint of the certificate, base64url-encoded without
  /// padding: the `x5t#S256` of the `cnf` of a token bound to it (RFC 8705
  /// §3.1).
  late final String thumbprint = base64Url
      .encode(sha256.convert(der).bytes)
      .replaceAll('=', '');
}
