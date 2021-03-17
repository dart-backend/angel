# combinator
[![version](https://img.shields.io/pub/v/combinator.svg)](https://pub.dartlang.org/packages/combinator)
[![build status](https://travis-ci.org/thosakwe/combinator.svg)](https://travis-ci.org/thosakwe/combinator)

Packrat parser combinators that support static typing, generics, file spans, memoization, and more.

**RECOMMENDED:**
Check `example/` for examples.
The examples contain examples of using:
* Generic typing
* Reading `FileSpan` from `ParseResult`
* More...

## Basic Usage
```dart
void main() {
  // Parse a Pattern (usually String or RegExp).
  var foo = match('foo');
  var number = match(new RegExp(r'[0-9]+'), errorMessage: 'Expected a number.');
  
  // Set a value.
  var numWithValue = number.map((r) => int.parse(r.span.text));
  
  // Expect a pattern, or nothing.
  var optional = numWithValue.opt();
  
  // Expect a pattern zero or more times.
  var star = optional.star();
  
  // Expect one or more times.
  var plus = optional.plus();
  
  // Expect an arbitrary number of times.
  var threeTimes = optional.times(3);
  
  // Expect a sequence of patterns.
  var doraTheExplorer = chain([
    match('Dora').space(),
    match('the').space(),
    match('Explorer').space(),
  ]);
  
  // Choose exactly one of a set of patterns, whichever
  // appears first.
  var alt = any([
    match('1'),
    match('11'),
    match('111'),
  ]);
  
  // Choose the *longest* match for any of the given alternatives.
  var alt2 = longest([
    match('1'),
    match('11'),
    match('111'),
  ]);
  
  // Friendly operators
  var fooOrNumber = foo | number;
  var fooAndNumber = foo & number;
  var notFoo = ~foo;
}
```

## Error Messages
Parsers without descriptive error messages can lead to frustrating dead-ends
for end-users. Fortunately, `combinator` is built with error handling in mind.

```dart
void main(Parser parser) {
  // Append an arbitrary error message to a parser if it is not matched.
  var withError = parser.error(errorMessage: 'Hey!!! Wrong!!!');
  
  // You can also set the severity of an error.
  var asHint = parser.error(severity: SyntaxErrorSeverity.hint);
  
  // Constructs like `any`, `chain`, and `longest` support this as well.
  var foo = longest([
    parser.error(errorMessage: 'foo'),
    parser.error(errorMessage: 'bar')
  ], errorMessage: 'Expected a "foo" or a "bar"');
  
  // If multiple errors are present at one location,
  // it can create a lot of noise.
  //
  // Use `foldErrors` to only take one error at a given location.
  var lessNoise = parser.foldErrors();
}
```

## Whitespaces
Handling optional whitespace is dead-easy:

```dart
void main(Parser parser) {
  var optionalSpace = parser.space();
}
```

## For Programming Languages
`combinator` was conceived to make writing parsers for complex grammars easier,
namely programming languages. Thus, there are functions built-in to make common constructs
easier:

```dart
void main(Parser parser) {
  var array = parser
                .separatedByComma()
                .surroundedBySquareBrackets(defaultValue: []);
  
  var braces = parser.surroundedByCurlyBraces();
  
  var sep = parser.separatedBy(match('!').space());
}
```

## Differences between this and Petitparser
* `combinator` makes extensive use of Dart's dynamic typing
* `combinator` supports detailed error messages (with configurable severity)
* `combinator` keeps track of locations (ex. `line 1: 3`)