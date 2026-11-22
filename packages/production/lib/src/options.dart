import 'dart:io';

import 'package:args/args.dart';

/// Options for executing Runner.
class RunnerOptions {
  /// Command line arguments
  static final ArgParser argParser = ArgParser()
    ..addFlag(
      'help',
      abbr: 'h',
      help: 'Print this help information.',
      negatable: false,
    )
    ..addFlag(
      'respawn',
      help: 'Automatically respawn crashed application instances.',
      defaultsTo: true,
      negatable: true,
    )
    ..addFlag(
      'use-zone',
      negatable: false,
      help: 'Create a new Zone for each request.',
    )
    ..addFlag('quiet', negatable: false, help: 'Completely mute logging.')
    ..addFlag(
      'ssl',
      negatable: false,
      help: 'Listen for HTTPS instead of HTTP.',
    )
    ..addFlag(
      'http2',
      negatable: false,
      help: 'Listen for HTTP/2 instead of HTTP/1.1.',
    )
    ..addOption(
      'address',
      abbr: 'a',
      defaultsTo: '127.0.0.1',
      help: 'The address to listen on.',
    )
    ..addOption(
      'concurrency',
      abbr: 'j',
      defaultsTo: Platform.numberOfProcessors.toString(),
      help: 'The number of isolates to spawn.',
    )
    ..addOption(
      'port',
      abbr: 'p',
      defaultsTo: '3000',
      help: 'The port to listen on.',
    )
    ..addOption('certificate-file', help: 'The PEM certificate file to read.')
    ..addOption(
      'certificate-password',
      help:
          'The PEM certificate file password; prefer $certificatePasswordVariable, as arguments are seen by other users.',
    )
    ..addOption('key-file', help: 'The PEM key file to read.')
    ..addOption(
      'key-password',
      help:
          'The PEM key file password; prefer $keyPasswordVariable, as arguments are seen by other users.',
    )
    ..addOption(
      'client-ca-file',
      help: 'The PEM file of the CAs that may sign client certificates: asks each client for one (mutual TLS).',
    )
    ..addFlag(
      'require-client-certificate',
      negatable: false,
      help: 'Refuse a client that presents no certificate; needs --client-ca-file.',
    );

  /// The environment variable of the certificate's password, used if
  /// `--certificate-password` is not given.
  static const String certificatePasswordVariable =
      'ANGEL_CERTIFICATE_PASSWORD';

  /// The environment variable of the key's password, used if
  /// `--key-password` is not given.
  static const String keyPasswordVariable = 'ANGEL_KEY_PASSWORD';

  /// The integer of the option [name], at least [min] and at most [max];
  /// throws an [ArgParserException] otherwise.
  static int _intOption(ArgResults results, String name, int min, int max) {
    var text = results[name] as String;
    var value = int.tryParse(text);
    if (value == null || value < min || value > max) {
      throw ArgParserException(
        'Invalid --$name "$text": expected a whole number from $min to $max.',
      );
    }
    return value;
  }

  final String hostname;
  final String? certificateFile, keyFile, certificatePassword, keyPassword;

  /// The PEM file of the CAs that may sign client certificates, of
  /// `--client-ca-file`: if given, the server asks each client for a
  /// certificate (mutual TLS), which `RequestContext.clientCertificate`
  /// gives, and trusts these CAs to sign it.
  final String? clientCaFile;

  /// Whether a client that presents no certificate fails the TLS
  /// handshake, of `--require-client-certificate`. Needs [clientCaFile].
  final bool requireClientCertificate;
  final int concurrency, port;
  final bool useZone, respawn, quiet, ssl, http2;
  final Map<String, Object?> removeResponseHeaders = {};
  final Map<String, Object> responseHeaders = {};

  /// Throws an [ArgumentError] of [ssl] or [http2] without a
  /// [certificateFile] and a [keyFile], of a [clientCaFile] without [ssl] or
  /// [http2], or of [requireClientCertificate] without [clientCaFile]: none
  /// of them could serve as asked.
  RunnerOptions({
    this.hostname = '127.0.0.1',
    this.port = 3000,
    this.concurrency = 1,
    this.useZone = false,
    this.respawn = true,
    this.quiet = false,
    this.certificateFile,
    this.keyFile,
    this.ssl = false,
    this.http2 = false,
    this.certificatePassword,
    this.keyPassword,
    this.clientCaFile,
    this.requireClientCertificate = false,
  }) {
    if (_problem(
          ssl: ssl,
          http2: http2,
          certificateFile: certificateFile,
          keyFile: keyFile,
          clientCaFile: clientCaFile,
          requireClientCertificate: requireClientCertificate,
        )
        case var problem?) {
      throw ArgumentError(problem);
    }
  }

  /// What is wrong with the TLS options, if anything.
  static String? _problem({
    required bool ssl,
    required bool http2,
    required String? certificateFile,
    required String? keyFile,
    required String? clientCaFile,
    required bool requireClientCertificate,
  }) {
    if ((ssl || http2) && certificateFile == null) {
      return 'Missing --certificate-file option.';
    } else if ((ssl || http2) && keyFile == null) {
      return 'Missing --key-file option.';
    } else if (clientCaFile != null && !ssl && !http2) {
      return '--client-ca-file needs --ssl or --http2.';
    } else if (requireClientCertificate && clientCaFile == null) {
      return '--require-client-certificate needs --client-ca-file.';
    }
    return null;
  }

  factory RunnerOptions.fromArgResults(ArgResults argResults) {
    var ssl = argResults['ssl'] as bool? ?? false;
    var http2 = argResults['http2'] as bool? ?? false;
    var certificateFile = argResults['certificate-file'] as String?;
    var keyFile = argResults['key-file'] as String?;
    var clientCaFile = argResults['client-ca-file'] as String?;
    var requireClientCertificate =
        argResults['require-client-certificate'] as bool? ?? false;
    if (_problem(
          ssl: ssl,
          http2: http2,
          certificateFile: certificateFile,
          keyFile: keyFile,
          clientCaFile: clientCaFile,
          requireClientCertificate: requireClientCertificate,
        )
        case var problem?) {
      throw ArgParserException(problem);
    }
    return RunnerOptions(
      hostname: argResults['address'] as String,
      port: _intOption(argResults, 'port', 0, 65535),
      concurrency: _intOption(argResults, 'concurrency', 1, 1024),
      useZone: argResults['use-zone'] as bool? ?? false,
      respawn: argResults['respawn'] as bool? ?? true,
      quiet: argResults['quiet'] as bool? ?? false,
      certificateFile: certificateFile,
      keyFile: keyFile,
      ssl: ssl,
      http2: http2,
      certificatePassword:
          argResults['certificate-password'] as String? ??
          Platform.environment[certificatePasswordVariable],
      keyPassword:
          argResults['key-password'] as String? ??
          Platform.environment[keyPasswordVariable],
      clientCaFile: clientCaFile,
      requireClientCertificate: requireClientCertificate,
    );
  }
}
