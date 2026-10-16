# Change Log

## 10.0.0

* **Breaking:** No longer uses `dart:mirrors`, so apps using it can be compiled with `dart compile exe`. In an expression such as `{{user.name}}`, each part after the first is read as a key of a `Map`, or of what the object's `toJson()` returns (as for `@serializable` models). The getters of other objects are no longer read, except for an index of a `List` (`{{items.0}}`) and `length`, `isEmpty`, `isNotEmpty`, `first` and `last` of a `String`, `List` or `Map`
* **Breaking:** The values of `{{...}}` expressions are put into the rendered HTML, HTML-escaped, so HTML and Markdown in them render as text instead of being injected into the page (an XSS hole when a value came from the request). They appear as given in code, tables and HTML attributes, and the ids of headings are generated from them. Pass `escape: false` to `markdown()` to insert trusted values into the Markdown as before
* fix: A view name that resolves outside the views directory, such as `../secret` or an absolute path, throws a 404 `AngelHttpException` instead of reading the file
* fix: Expressions into `Map` locals, such as `{{user.name}}` with `{'user': {'name': 'Bob'}}`, resolve; they threw `NoSuchMethodError`
* fix: A missing key, a `null` value or an object without `toJson()` in the middle of an expression throws an `ArgumentError` naming the expression
* fix: Spaces around an expression and its parts are ignored, so `{{ title }}` reads the local `title`; it threw because no local was named `" title"`
* fix: An expression whose value is `null` renders as nothing, instead of as the text `null`
* fix: The example escapes the `title` it puts into the page's `<title>`
* test: Added tests for interpolation, escaping and view names
* Released with the other Angel3 packages at 10.0.0

## 9.1.0

* Require Dart >= 3.13

## 9.0.0

* Require Dart >= 3.12

## 8.4.0

* Require Dart >= 3.8
* Updated `lints` to 6.0.0
* Updated dependencies to the latest release

## 8.3.0

* Require Dart >= 3.6
* Updated `lints` to 5.0.0
* Updated dependencies to the latest release

## 8.2.0

* Require Dart >= 3.3
* Updated `lints` to 4.0.0

## 8.1.1

* Updated repository link

## 8.1.0

* Updated `lints` to 3.0.0
* Fixed linter warnings

## 8.0.0

* Require Dart >= 3.0

## 7.0.0

* Require Dart >= 2.17
* Updated `markdown` to 6.0.x

## 6.1.0

* Updated `markdown` to 5.x.x

## 6.0.0

* Require Dart >= 2.16

## 5.0.0

* Skipped release

## 4.1.0

* Updated linter to `package:lints`

## 4.0.0

* Migrated to support Dart >= 2.12 NNBD
  
## 3.0.0

* Migrated to support Dart >= 2.12 Non NNBD

## 2.0.0

* Angel 2 + Dart 2 updates.
* Use `package:file`.
