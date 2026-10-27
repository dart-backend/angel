# Change Log

## 10.0.0

### Fixes in 10.0.0

* **Security:** An asset is a file of the asset directory, with a leading `/` its root; `../` and absolute paths could inline any file of the server into a page. `/site.css` was looked up at the root of the file system, and so never inlined. References with a host are left as they are
* **Inlining:** Content is inlined as text, with `</script` and `</style` escaped. Stylesheets keep `media` and `nonce`; `async` and non-module `defer` scripts stay external; elements without a valid `href`/`src` are skipped; `rel` is read as a list of words, and stylesheets in the body are inlined too
* **`inlineAssetsFromVirtualDirectory`:** Serves the inlined page through the directory it wraps, so caching, `Range` and `callback` apply, with an ETag of the page and its assets. It keeps `useBuffer` and `followLinksOutsideSource`, and inlines `.htm` and extensions of any case
* **Charset:** `inlineAssets` decodes the page's declared charset and sends UTF-8, with a matching `<meta charset>`
* **Docs:** The README tells how to install and use the package, and its examples are up to date


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
