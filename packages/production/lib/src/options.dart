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
  final int concurrency, port;
  final bool useZone, respawn, quiet, ssl, http2;
  final Map<String, Object> removeResponseHeaders = {};
  final Map<String, Object> responseHeaders = {};

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
  });

  factory RunnerOptions.fromArgResults(ArgResults argResults) {
    return RunnerOptions(
      hostname: argResults['address'] as String,
      port: _intOption(argResults, 'port', 0, 65535),
      concurrency: _intOption(argResults, 'concurrency', 1, 1024),
      useZone: argResults['use-zone'] as bool? ?? false,
      respawn: argResults['respawn'] as bool? ?? true,
      quiet: argResults['quiet'] as bool? ?? false,
      certificateFile: argResults['certificate-file'] as String?,
      keyFile: argResults['key-file'] as String?,
      ssl: argResults['ssl'] as bool? ?? false,
      http2: argResults['http2'] as bool? ?? false,
      certificatePassword:
          argResults['certificate-password'] as String? ??
          Platform.environment[certificatePasswordVariable],
      keyPassword:
          argResults['key-password'] as String? ??
          Platform.environment[keyPasswordVariable],
    );
  }
}
