# Angel3 Validate

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_validate?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/validate/LICENSE)

This validator library is based on the `matcher` library and comes with build in support for Angel3 framework. It can be run on both server and client side. Thus, the same validation rules apply to forms on both backend and frontend code.

For convenience's sake, this library also exports `matcher`.

- [Angel3 Validate](#angel3-validate)
  - [Examples](#examples)
    - [Creating a Validator](#creating-a-validator)
    - [Validating data](#validating-data)
    - [Required Fields](#required-fields)
    - [Forbidden Fields](#forbidden-fields)
    - [Default values](#default-values)
    - [Custom Validator Functions](#custom-validator-functions)
    - [Custom Error Messages](#custom-error-messages)
    - [autoParse](#autoparse)
    - [filter](#filter)
    - [Extending Validators](#extending-validators)
    - [Bundled Matchers](#bundled-matchers)
    - [Nested Validators](#nested-validators)
    - [Use with Angel3](#use-with-angel3)

## Examples

### Creating a Validator

```dart
import 'package:angel3_validate/angel3_validate.dart';

main() {
    var validator = Validator({
        'username': isAlphaNum,
        'multiple,keys,with,same,rules': [isString, isNotEmpty],
        'balance': [
            greaterThanOrEqualTo(0),
            lessThan(1000000)
        ],
        'nested': [
            foo,
            [bar, baz]
        ]
    });
}
```

### Validating data

The `Validator` will filter out fields that have no validation rules. You can rest easy knowing that attackers cannot slip extra data into your applications.

```dart
main() {
    var result = validator.check(formData);

    if (!result.errors.isNotEmpty) {
        // Invalid data
    } else {
        // Safely handle filtered data
        return someSecureOperation(result.data);
    }
}
```

You can `enforce` validation rules, and throw an error if validation fails.

```dart
main() {
    try {
        // `enforce` will return the filtered data.
        var safeData = validator.enforce(formData);
    } on ValidationException catch(e) {
        print(e.errors);
    }
}
```

### Required Fields

Fields are optional by default. Suffix a field name with a `'*'` to mark it as required, and to throw an error if it is not present.

```dart
main() {
    var validator = Validator({
        'googleId*': isString,
        
        // You can also use `requireField`
        requireField('googleId'): isString,
    });
}
```

### Forbidden Fields

To prevent a field from showing up in valid data, suffix it with a `'!'`.

### Default values

If not present, default values will be filled in *before* validation. This means that they can still be used with required fields.

```dart
final Validator todo = Validator({
    'text*': isString,
    'completed*': isBool
}, defaultValues: {
    'completed': false
});
```

Default values can also be parameterless, *synchronous* functions that return a single value.

### Custom Validator Functions

Creating a whole `Matcher` class is sometimes cumbersome, but if you pass a function to the constructor, it will be wrapped in a `Matcher` instance. (It simply returns the value of calling [`predicate`](https://pub.dev/documentation/matcher/latest/matcher/predicate.html).)

The function must *synchronously* return a `bool`.

```dart
main() {
    var validator = Validator({
        'key*': (key) {
            var file = File('whitelist.txt');
            return file.readFileSync().contains(key);
        }
    });
}
```

### Custom Error Messages

If these are not present, `angel3_validate` will *attempt* to generate a coherent error message on its own.

```dart
Validator({
    'age': [greaterThanOrEqualTo(18)]
}, customErrorMessages: {
    'age': 'You must be an adult to see this page.'
});
```

The string `{{value}}` will be replaced inside your error message automatically.

### autoParse

Oftentimes, fields that we want to validate as numbers are passed as strings. Calling `autoParse` will correct this before validation.

```dart
main() {
    var parsed = autoParse({
        'age': '34',
        'weight': '135.6'
    }, ['age', 'weight']);

    validator.enforce(parsed);
}
```

You can also call `checkParsed` or `enforceParsed` as a shorthand.

### filter

This is a helper function to extract only the desired keys from a `Map`.

```dart
var inputData = {'foo': 'bar', 'a': 'b', '1': 2};
var only = filter(inputData, ['foo']);

print(only); // { foo: bar }
```

### Extending Validators

You can add situation-specific rules within a child validator. You can also use `extend` to mark fields as required or forbidden that originally were not. Default value and custom error message extension is also supported.

```dart
final Validator userValidator = Validator({
    'username': isString,
    'age': [
        isNum,
        greaterThanOrEqualTo(18)
    ]
});
```

To mark a field as now optional, and no longer required, suffix its name with a `'?'`.

```dart
var ageIsOptional = userValidator.extend({
    'age?': [
        isNum,
        greaterThanOrEqualTo(13)
    ]
});
```

Note that by default, validation rules are simply appended to the existing list. To completely overwrite existing rules, set the `overwrite` flag to `true`.

```dart
register(Map userData) {
    var teenUser = userValidator.extend({
        'age': lessThan(18)
    }, overwrite: true);    
}
```

### Bundled Matchers

This library includes some `Matcher`s for common validations, including:

- `isAlphaDash`: Asserts that a `String` is alphanumeric, but also lets it contain dashes or underscores.
- `isAlphaNum`: Asserts that a `String` is alphanumeric.
- `isBool`: Asserts that a value either equals `true` or `false`.
- `isEmail`: Asserts that a `String` complies to the RFC 5322 e-mail standard.
- `isInt`: Asserts that a value is an `int`.
- `isNum`: Asserts that a value is a `num`.
- `isString`: Asserts that a value is a `String`.
- `isNonEmptyString`: Asserts that a value is a non-empty `String`.
- `isUrl`: Asserts that a `String` is an HTTPS or HTTP URL.

The remaining functionality is [effectively implemented by the `matcher` package](https://pub.dev/documentation/matcher/latest/matcher/matcher-library.html).

### Nested Validators

Very often, the data we validate contains other data within. You can pass a `Validator` instance to the constructor, because it extends the `Matcher` class.

```dart
main() {
    var bio = Validator({
        'age*': [isInt, greaterThanOrEqualTo(0)],
        'birthYear*': isInt,
        'countryOfOrigin': isString
    });

    var book = Validator({
        'title*': isString,
        'year*': [
            isNum,
            (year) {
                return year <= DateTime.now().year;
            }
        ]
    });

    var author = Validator({
        'bio*': bio,
        'books*': [
            isList,
            everyElement(book)
        ]
    }, defaultValues: {
        'books': []
    });
}
```

### Use with Angel3

`server.dart` exposes seven helper middleware:

- `validate(validator)`: Validates and filters `req.bodyAsMap`, and throws an `AngelHttpException.BadRequest` if data is invalid.
- `validateEvent(validator)`: Sets `e.data` to the result of validation on a service event.
- `validateQuery(validator)`: Same as `validate`, but operates on `req.query`.
- `autoParseBody(fields)`: Auto-parses numbers in `req.bodyAsMap`.
- `autoParseQuery(fields)`: Same as `autoParseBody`, but operates on `req.query`.
- `filterBody(only)`: Filters unwanted data out of `req.bodyAsMap`.
- `filterQuery(only)`: Same as `filterBody`, but operates on `req.query`.

```dart
import 'package:angel3_framework/angel3_framework.dart';
import 'package:angel3_validate/server.dart';

final Validator echo = Validator({
    'message*': (String message) => message.length >= 5
});

final Validator todo = Validator({
    'text*': isString,
    'completed*': isBool
}, defaultValues: {
    'completed': false
});

void main() async {
    var app = Angel();

    app.chain([validate(echo)]).post('/echo', (req, res) async {
        res.write('You said: "${req.bodyAsMap["message"]}"');
    });

    app.service('api/todos')
        ..beforeCreated.listen(validateEvent(todo))
        ..beforeUpdated.listen(validateEvent(todo));

    await app.startServer();
}
```
