import 'dart:io';

/// Isolates to serve with: `ISOLATES`, else one per processor (as issue 2).
int get isolateCount =>
    int.tryParse(Platform.environment['ISOLATES'] ?? '') ??
    Platform.numberOfProcessors;

/// The port to listen on: `PORT`, else 3000 (as issue 2).
int get port => int.tryParse(Platform.environment['PORT'] ?? '') ?? 3000;
