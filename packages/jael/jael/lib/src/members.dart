/// Reads the member [name] of [target] for a template's `target.name`, or
/// returns [noMember] if it does not know it.
///
/// Give one to `Renderer.render` for the members of the application's own
/// classes, which are otherwise read only through their `toJson()`. That of
/// `angel3_jael` reads them through the app's reflector, such as a
/// `StaticReflector` of the data `angel3_container_generator` generates.
typedef MemberResolver = Object? Function(Object? target, String name);

/// Returned by a [MemberResolver] that does not know a member.
const Object noMember = _NoMember();

class _NoMember {
  const _NoMember();

  @override
  String toString() => 'noMember';
}

/// The member [name] of [target], as a template reads it:
///
/// 1. that of [resolver], if it knows it;
/// 2. the value of the key [name] of a [Map];
/// 3. a common member of a core type, such as `length` of a [String] or an
///    [Iterable], `toInt` of a [num], or `year` of a [DateTime];
/// 4. the value of the key [name] of the `toJson()` of [target].
///
/// Throws a [NoSuchMethodError] if none has it.
Object? readMember(Object? target, String name, [MemberResolver? resolver]) {
  if (resolver != null) {
    var value = resolver(target, name);
    if (!identical(value, noMember)) return value;
  }

  if (target is Map && target.containsKey(name)) return target[name];

  var value = _coreMember(target, name);
  if (!identical(value, noMember)) return value;

  if (target != null && target is! Map) {
    Object? json;
    try {
      json = (target as dynamic).toJson();
    } on NoSuchMethodError {
      // It has none.
    }
    if (json is Map && json.containsKey(name)) return json[name];
  }

  throw NoSuchMethodError.withInvocation(
    target,
    Invocation.getter(Symbol(name)),
  );
}

/// The member [name] of [target] of a core type, or [noMember].
Object? _coreMember(Object? target, String name) {
  var value = switch (target) {
    String s => _string(s, name),
    List l => _list(l, name),
    Iterable i => _iterable(i, name),
    Map m => _map(m, name),
    MapEntry e => switch (name) {
      'key' => e.key,
      'value' => e.value,
      _ => noMember,
    },
    int i => _int(i, name),
    num n => _num(n, name),
    DateTime d => _dateTime(d, name),
    Duration d => _duration(d, name),
    _ => noMember,
  };
  if (!identical(value, noMember)) return value;

  return switch (name) {
    'toString' => target.toString,
    'hashCode' => target.hashCode,
    'runtimeType' => target.runtimeType,
    _ => noMember,
  };
}

Object? _string(String s, String name) => switch (name) {
  'length' => s.length,
  'isEmpty' => s.isEmpty,
  'isNotEmpty' => s.isNotEmpty,
  'toUpperCase' => s.toUpperCase,
  'toLowerCase' => s.toLowerCase,
  'trim' => s.trim,
  'trimLeft' => s.trimLeft,
  'trimRight' => s.trimRight,
  'contains' => s.contains,
  'startsWith' => s.startsWith,
  'endsWith' => s.endsWith,
  'indexOf' => s.indexOf,
  'lastIndexOf' => s.lastIndexOf,
  'substring' => s.substring,
  'split' => s.split,
  'replaceAll' => s.replaceAll,
  'replaceFirst' => s.replaceFirst,
  'padLeft' => s.padLeft,
  'padRight' => s.padRight,
  'codeUnits' => s.codeUnits,
  _ => noMember,
};

Object? _list(List l, String name) => switch (name) {
  'reversed' => l.reversed,
  'indexOf' => l.indexOf,
  'lastIndexOf' => l.lastIndexOf,
  'sublist' => l.sublist,
  'asMap' => l.asMap,
  _ => _iterable(l, name),
};

Object? _iterable(Iterable i, String name) => switch (name) {
  'length' => i.length,
  'isEmpty' => i.isEmpty,
  'isNotEmpty' => i.isNotEmpty,
  'first' => i.first,
  'last' => i.last,
  'single' => i.single,
  'contains' => i.contains,
  'elementAt' => i.elementAt,
  'join' => i.join,
  'map' => i.map,
  'where' => i.where,
  'any' => i.any,
  'every' => i.every,
  'take' => i.take,
  'skip' => i.skip,
  'toList' => i.toList,
  'toSet' => i.toSet,
  _ => noMember,
};

Object? _map(Map m, String name) => switch (name) {
  'length' => m.length,
  'isEmpty' => m.isEmpty,
  'isNotEmpty' => m.isNotEmpty,
  'keys' => m.keys,
  'values' => m.values,
  'entries' => m.entries,
  'containsKey' => m.containsKey,
  'containsValue' => m.containsValue,
  _ => noMember,
};

Object? _int(int i, String name) => switch (name) {
  'isEven' => i.isEven,
  'isOdd' => i.isOdd,
  _ => _num(i, name),
};

Object? _num(num n, String name) => switch (name) {
  'toInt' => n.toInt,
  'toDouble' => n.toDouble,
  'round' => n.round,
  'floor' => n.floor,
  'ceil' => n.ceil,
  'truncate' => n.truncate,
  'abs' => n.abs,
  'clamp' => n.clamp,
  'toStringAsFixed' => n.toStringAsFixed,
  'toStringAsPrecision' => n.toStringAsPrecision,
  'isNaN' => n.isNaN,
  'isNegative' => n.isNegative,
  'isFinite' => n.isFinite,
  'sign' => n.sign,
  _ => noMember,
};

Object? _dateTime(DateTime d, String name) => switch (name) {
  'year' => d.year,
  'month' => d.month,
  'day' => d.day,
  'hour' => d.hour,
  'minute' => d.minute,
  'second' => d.second,
  'millisecond' => d.millisecond,
  'microsecond' => d.microsecond,
  'weekday' => d.weekday,
  'isUtc' => d.isUtc,
  'millisecondsSinceEpoch' => d.millisecondsSinceEpoch,
  'toIso8601String' => d.toIso8601String,
  'toLocal' => d.toLocal,
  'toUtc' => d.toUtc,
  'add' => d.add,
  'subtract' => d.subtract,
  'difference' => d.difference,
  'isBefore' => d.isBefore,
  'isAfter' => d.isAfter,
  _ => noMember,
};

Object? _duration(Duration d, String name) => switch (name) {
  'inDays' => d.inDays,
  'inHours' => d.inHours,
  'inMinutes' => d.inMinutes,
  'inSeconds' => d.inSeconds,
  'inMilliseconds' => d.inMilliseconds,
  'inMicroseconds' => d.inMicroseconds,
  'isNegative' => d.isNegative,
  _ => noMember,
};
