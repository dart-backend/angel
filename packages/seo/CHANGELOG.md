# Change Log

## 10.0.0

* fix: An asset is a file of the asset directory: a leading `/` is its root, where `/site.css` was read from the root of the file system and so never inlined, and a path out of it is not inlined, where `../` or an absolute path inlined any file of the server into the page (e.g. of HTML that includes user content). A reference with a host (`//cdn.example/x.css`) is left as it is
* fix: Assets are inlined as text, with `</script` and `</style` escaped, where a script or stylesheet holding its end tag ended its element early, and the rest of it was read as markup
* fix: A stylesheet keeps its `media` and `nonce`, where a print stylesheet applied to the screen; a script that is `async`, or `defer` but not a module, stays external, where it ran at once, before the document it was deferred for. A `link` or `script` without a valid `href` or `src` is left as it is, where it failed the response. A stylesheet's `rel` is read as a list of words, of any case, and stylesheets in the body are inlined too
* fix: `inlineAssetsFromVirtualDirectory` serves the inlined page with the directory it wraps, so the caching headers and `304`s of a `CachingVirtualDirectory`, `Range` requests and its `callback` apply, where the page was written as it was; its `Last-Modified` and ETag are of the latest of the page and its assets. It keeps `useBuffer` and `followLinksOutsideSource`, and inlines `.htm` files and extensions of any case. It compiles with the `serveFile` of `angel3_static` 10.0.0
* fix: `inlineAssets` decodes a page of its declared charset, and sends it as UTF-8, with a `<meta charset>` to match, where it decoded every page as UTF-8
* docs: The README examples use `app.fallback` and `inlineAssetsFromVirtualDirectory`, and no longer `lazyParseBodies`
* test: `inlining_test.dart`
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

## 6.0.0

* Require Dart >= 2.16

## 5.0.0

* Skipped release

## 4.1.0

* Updated linter to `package:lints`

## 4.0.0

* Updated to use `angel3` packages
* Published with `angel3` prefix

## 3.0.0

* Migrated to support Dart >= 2.12 NNBD

## 2.0.0

* Angel 2 updates.

## 1.0.0

* Initial release
