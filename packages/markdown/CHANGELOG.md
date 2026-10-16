# Change Log

## 10.0.0

* **Breaking:** No longer uses `dart:mirrors`, so apps using it can be compiled with `dart compile exe`. In an expression such as `{{user.name}}`, each part after the first is read as a key of a `Map`, or of what the object's `toJson()` returns (as for `@serializable` models). The getters of other objects are no longer read, except for an index of a `List` (`{{items.0}}`), `length`, `isEmpty` and `isNotEmpty` of a `String`, `Iterable` or `Map`, and `first` and `last` of an `Iterable`
* **Breaking:** The values of `{{...}}` expressions are put into the rendered HTML, HTML-escaped, so HTML and Markdown in them render as text instead of being injected into the page (an XSS hole when a value came from the request). They appear as given in code, tables and quoted HTML attributes, are percent-encoded in the URLs of Markdown links (as a component, e.g. in `/search?q={{q}}`, unless the value starts the URL), and the ids of headings are generated as for the Markdown with the values. Because Markdown no longer sees their content, a value cannot form Markdown syntax with the text around it: `<{{url}}>` and a bare `{{url}}` no longer become links (use `[{{url}}]({{url}})`). Equal values have equal placeholders, so reference links and footnotes whose labels have values still resolve. The URL of a Markdown link or image with values is replaced with `#` when its scheme is not `http`, `https` or `mailto` (such as `javascript:`), or when it starts with a value and `//`. Values are not escaped for JavaScript or CSS, and URLs in HTML attributes are not checked. Pass `escape: false` to `markdown()` to insert trusted values into the Markdown as before
* fix: A view name that resolves outside the views directory, such as `../secret` or an absolute path, or a path through a symbolic link that leads outside it, throws a 404 `AngelHttpException` instead of reading the file. A view that does not exist also throws a 404, instead of a `FileSystemException`
* fix: Expressions into `Map` locals, such as `{{user.name}}` with `{'user': {'name': 'Bob'}}`, resolve; they threw `NoSuchMethodError`
* fix: A missing key, a `null` value or an object without `toJson()` in the middle of an expression throws an `ArgumentError` naming the expression
* fix: Only the keys of what `toJson()` returns are read from an object, so `{{cart.length}}` does not read the number of its JSON keys. A `NoSuchMethodError` thrown inside `toJson()` is passed on as it is, instead of reported as a missing `toJson()`
* `toJson()` is called once per object in a render
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
