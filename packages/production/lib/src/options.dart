import 'dart:io';
import 'package:args/args.dart';

/// Options for executing Runner.
class RunnerOptions {
  /// Command line arguements
  static final ArgParser argParser = ArgParser()
    ..addFlag('help',
        abbr: 'h', help: 'Print this help information.', negatable: false)
    ..addFlag('respawn',
        help: 'Automatically respawn crashed application instances.',
        defaultsTo: true,
        negatable: true)
    ..addFlag('use-zone',
        negatable: false, help: 'Create a new Zone for each request.')
    ..addFlag('quiet', negatable: false, help: 'Completely mute logging.')
    ..addFlag('ssl',
        negatable: false, help: 'Listen for HTTPS instead of HTTP.')
    ..addFlag('http2',
        negatable: false, help: 'Listen for HTTP/2 instead of HTTP/1.1.')
    ..addOption('address',
        abbr: 'a', defaultsTo: '127.0.0.1', help: 'The address to listen on.')
    ..addOption('concurrency',
        abbr: 'j',
        defaultsTo: Platform.numberOfProcessors.toString(),
        help: 'The number of isolates to spawn.')
    ..addOption('port',
        abbr: 'p', defaultsTo: '3000', help: 'The port to listen on.')
    ..addOption('certificate-file', help: 'The PEM certificate file to read.')
    ..addOption('certificate-password',
        help: 'The PEM certificate file password.')
    ..addOption('key-file', help: 'The PEM key file to read.')
    ..addOption('key-password', help: 'The PEM key file password.');

  final String hostname;
  final String? certificateFile, keyFile, certificatePassword, keyPassword;
  final int concurrency, port;
  final bool useZone, respawn, quiet, ssl, http2;
  final Map<String, Object> removeResponseHeaders = {};
  final Map<String, Object> responseHeaders = {};

  RunnerOptions(
      {this.hostname = '127.0.0.1',
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
      this.keyPassword});

  factory RunnerOptions.fromArgResults(ArgResults argResults) {
    return RunnerOptions(
      hostname: argResults['address'] as String,
      port: int.parse(argResults['port'] as String),
      concurrency: int.parse(argResults['concurrency'] as String),
      useZone: argResults['use-zone'] as bool? ?? false,
      respawn: argResults['respawn'] as bool? ?? true,
      quiet: argResults['quiet'] as bool? ?? false,
      certificateFile: argResults['certificate-file'] as String?,
      keyFile: argResults['key-file'] as String?,
      ssl: argResults['ssl'] as bool? ?? false,
      http2: argResults['http2'] as bool? ?? false,
      certificatePassword: argResults['certificate-password'] as String?,
      keyPassword: argResults['key-password'] as String?,
    );
  }
}
