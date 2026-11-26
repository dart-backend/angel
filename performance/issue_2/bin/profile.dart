/// Samples the CPU of every isolate of a server started with `--observe`,
/// for as long as load is applied, and prints where the time went.
///
/// ```sh
/// dart run --observe=8181/127.0.0.1 --disable-service-auth-codes bin/angel.dart &
/// dart run bin/profile.dart ws://127.0.0.1:8181/ws 10 &
/// build/load/bundle/bin/load -d 10 'GET /user/*'
/// ```
///
/// Self time counts the frame on top of each sample, inclusive time every
/// frame on its stack (once per sample). Time spent in `dart:async` is also
/// charged to the first caller outside it, to show what the futures are of.
library;

import 'dart:io';

import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

Future<void> main(List<String> args) async {
  var uri = args.isNotEmpty ? args[0] : 'ws://127.0.0.1:8181/ws';
  var seconds = args.length > 1 ? int.parse(args[1]) : 10;
  var top = args.length > 2 ? int.parse(args[2]) : 40;

  var service = await vmServiceConnectUri(uri);
  var vm = await service.getVM();
  var isolates = [
    for (var ref in vm.isolates ?? <IsolateRef>[])
      if (ref.isSystemIsolate != true) ref.id!,
  ];

  var start = (await service.getVMTimelineMicros()).timestamp!;
  for (var id in isolates) {
    await service.clearCpuSamples(id);
  }
  await Future<void>.delayed(Duration(seconds: seconds));
  var end = (await service.getVMTimelineMicros()).timestamp!;

  var self = <String, int>{};
  var inclusive = <String, int>{};
  var byLibrary = <String, int>{};
  // Time in dart:async, charged to the first caller outside it.
  var asyncByCaller = <String, int>{};
  var asyncTotal = 0;
  var total = 0;
  for (var id in isolates) {
    var samples = await service.getCpuSamples(id, start, end - start);
    var functions = samples.functions ?? <ProfileFunction>[];
    var names = [for (var f in functions) _name(f)];
    var libraries = [for (var f in functions) _library(f)];
    for (var sample in samples.samples ?? <CpuSample>[]) {
      var stack = sample.stack ?? const <int>[];
      if (stack.isEmpty) continue;
      total++;
      self.update(names[stack.first], (n) => n + 1, ifAbsent: () => 1);
      byLibrary.update(libraries[stack.first], (n) => n + 1, ifAbsent: () => 1);
      if (_isAsync(functions[stack.first])) {
        asyncTotal++;
        ProfileFunction? caller;
        for (var i in stack) {
          if (!_isAsync(functions[i])) {
            caller = functions[i];
            break;
          }
        }
        var name = caller == null || _isScheduler(caller)
            ? '(a microtask or event, no caller)'
            : _name(caller);
        asyncByCaller.update(name, (n) => n + 1, ifAbsent: () => 1);
      }
      for (var name in {for (var i in stack) names[i]}) {
        inclusive.update(name, (n) => n + 1, ifAbsent: () => 1);
      }
    }
  }
  await service.dispose();

  String pct(int n) => (100 * n / total).toStringAsFixed(1).padLeft(5);
  void table(String title, Map<String, int> counts, int limit) {
    print('\n## $title\n');
    var sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (var e in sorted.take(limit)) {
      print('${pct(e.value)}%  ${e.key}');
    }
  }

  print('# $total samples over ${isolates.length} isolates, ${seconds}s');
  table('Self time by library', byLibrary, 20);
  table('Self time by function', self, top);
  table('Inclusive time by function', inclusive, top);
  print('\n# dart:async self time: ${pct(asyncTotal).trim()}% of all samples');
  table('dart:async self time by first caller outside it', asyncByCaller, 30);
  exit(0);
}

String _name(ProfileFunction f) {
  var fn = f.function;
  var name = switch (fn) {
    FuncRef(:var name, :var owner) => switch (owner) {
      ClassRef(name: var c) => '$c.$name',
      FuncRef(name: var o) => '$o.$name',
      _ => name ?? '?',
    },
    NativeFunction(:var name) => '[native] $name',
    _ => '$fn',
  };
  return '$name  (${_library(f)})';
}

/// Whether [f] is of `dart:async`, where futures, streams and zones are.
bool _isAsync(ProfileFunction f) =>
    (f.resolvedUrl ?? '').contains('/sdk/lib/async/');

/// Whether [f] runs microtasks or events, so has no caller of its own.
bool _isScheduler(ProfileFunction f) =>
    (f.resolvedUrl ?? '').contains('isolate_patch.dart');

String _library(ProfileFunction f) {
  var uri = f.resolvedUrl ?? '';
  if (uri.isEmpty) return f.kind == 'Native' ? '[native]' : '[vm]';
  if (uri.startsWith('dart:')) return uri.split('/').first;
  var package =
      RegExp(r'package:([^/]+)/').firstMatch(uri) ??
      RegExp(r'/(?:pub\.dev|packages)/([^/]+?)(?:-[\d.]+)?/lib/')
          .firstMatch(uri);
  return package != null ? 'package:${package[1]}' : uri;
}
