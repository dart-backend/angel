import 'dart:collection' as col;

import 'package:angel3_container/angel3_container.dart';

import 'base.dart';
import 'other_base.dart';

part 'services.g.dart';

const _defaultRetries = 3;

@injectable
class Config {
  final String name;

  Config([this.name = 'default']);
}

@injectable
class Logger {}

@injectable
class Greeter {
  final Config config;
  final Logger? log;
  final int retries;
  final col.Queue<int>? queue;

  Greeter(this.config, {this.log, this.retries = _defaultRetries, this.queue});
}

@injectable
class Mailer {
  final Config config;

  Mailer({required this.config});
}

/// Abstract, with a factory constructor: can be made.
@injectable
abstract class Clock {
  factory Clock() => _SystemClock();

  DateTime now();
}

class _SystemClock implements Clock {
  @override
  DateTime now() => DateTime.now();
}

/// Abstract, without a factory constructor: cannot be made.
@injectable
abstract class Shape {}

typedef Handler = void Function();

/// Types that must be written out, with this library's prefixes.
@injectable
class Callbacks {
  final void Function(col.Queue<int>)? onQueue;
  final (int, {String s})? pair;
  final (int,)? single;
  final Handler? handler;

  Callbacks({this.onQueue, this.pair, this.single, this.handler});
}

/// `$` in the class and parameter names.
@injectable
class Pay$Pal {
  final int a$b;

  Pay$Pal({this.a$b = 1});
}

/// A `super.` parameter whose type its superclass's library imports without
/// the prefix this library uses.
@injectable
class Sub extends Base {
  Sub(super.ids);
}

/// A default that names a static member of the class.
@injectable
class Limits {
  static const defaultMax = 10;
  final int max;

  Limits({this.max = defaultMax});
}

/// A default that is implicitly const (`[]`), so the same list every time.
@injectable
class Labels {
  final List<String> labels;

  Labels({this.labels = const []});
}

/// A `super.` parameter that inherits its default from another library.
@injectable
class Retrying extends RetryBase {
  Retrying({super.retries});
}

/// Not annotated: no reflection data.
class NotInjectable {}

/// The members of an instance, which `getMember` reads, as a template does.
@injectable
class Profile extends Base {
  final String name = 'Ann';
  String? nickname;

  Profile(super.ids);

  String get greeting => 'Hello, $name';

  String shout() => name.toUpperCase();

  static String get kind => 'profile';

  String get _secret => 'hidden';

  String revealed() => _secret;
}
