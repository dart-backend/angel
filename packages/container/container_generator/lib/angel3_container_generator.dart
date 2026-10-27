/// Generates the reflection data `package:angel3_container` needs to
/// construct `@injectable` classes without `dart:mirrors`.
library;

import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/generator.dart';

export 'src/generator.dart'
    show StaticReflectionGenerator, reflectionVariableName;

/// The `static_reflection` builder: a part of each library with
/// `@injectable` classes, combined into its `.g.dart` file.
Builder staticReflectionBuilder(BuilderOptions options) =>
    SharedPartBuilder([StaticReflectionGenerator()], 'static_reflection');
