# JAEL3

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/jael3?include_prereleases)

A simple server-side HTML templating engine for Dart.

Though its syntax is but a superset of HTML, it supports features such as:

* **Custom elements**
* Loops
* Conditionals
* Template inheritance
* Block scoping
* `switch` syntax
* Interpolation of any Dart expression

Jael3 is a good choice for applications of any scale, especially when the development team is small, or the time invested in building an SPA would be too much.

## Documentation

Each of the [packages within this repository](#this-repository) contains some sort of documentation.

Documentation for Jael syntax and directives has been **moved** to the [Angel3 framework wiki](https://angel3-docs.dukefirehawk.com/packages/front-end/jael).

## This Repository

Within this repository are three packages:

* `package:jael3` - Contains the Jael parser, AST, and HTML renderer.
* `package:jael3_preprocessor` - Handles template inheritance, and facilitates the use of "compile-time" constructs.
* `package:angel3_jael` - [Angel3](https://angel3-framework.web.app/) support for Jael.
