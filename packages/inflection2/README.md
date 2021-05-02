# Forked
**IMPORTANT NOTE**: This is a *hard fork* of the original `inflection` package,
as the former is now archived, and abandoned.

# Inflection

[![Build Status](https://travis-ci.org/thosakwe/dart-inflection.svg)](https://travis-ci.org/thosakwe/dart-inflection)

In grammar, inflection or inflexion is the modification of a word to express 
different grammatical categories such as tense, mood, voice, aspect, person, 
number, gender and case.

A port of the Rails/ActiveSupport inflector library to Dart.

## Usage

A simple usage example:

```dart
import 'package:inflection2/inflection2.dart';

main() {
  // Using 'shortcut' functions.
  
  print(pluralize("house")); // => "houses"
  print(convertToPlural("house")); // => "houses", alias for pluralize
  print(pluralizeVerb("goes")); // => "go"
  print(singularize("axes")); // => "axis"
  print(convertToSingular("axes")); // => "axis", alias for pluralize
  print(singularizeVerb("write")); // => "writes"
  print(convertToSnakeCase("CamelCaseName")); // => "camel_case_name"
  print(convertToSpinalCase("CamelCaseName")); // => "camel-case-name"
  print(past("forgo")); // => "forwent"

  // Using default encoders.
  
  print(PLURAL.convert("virus")); // => "viri"
  print(SINGULAR.convert("Matrices")); // => "Matrix"
  print(SINGULAR.convert("species")); // => "species"
  print(SNAKE_CASE.convert("CamelCaseName")); // => "camel_case_name"
  print(SPINAL_CASE.convert("CamelCaseName")); // => "camel-case-name"
  print(PAST.convert("miss")); // => "missed"
}
```

## Features and bugs

Please file feature requests and bugs at the 
[issue tracker](https://github.com/thosakwe/dart-inflection/issues).
