import '../lib/inflection2.dart';

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
