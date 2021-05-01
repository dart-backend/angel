[![The Angel Framework](https://angel-dart.github.io/assets/images/logo.png)](https://angel-dart.dev)

[![Gitter](https://img.shields.io/gitter/room/nwjs/nw.js.svg)](https://gitter.im/angel_dart/discussion)
[![Pub](https://img.shields.io/pub/v/angel_framework.svg)](https://pub.dartlang.org/packages/angel_framework)
[![Build status](https://travis-ci.org/angel-dart/framework.svg?branch=master)](https://travis-ci.org/angel-dart/framework)
![License](https://img.shields.io/github/license/angel-dart/framework.svg)

**A polished, production-ready backend framework in Dart.**

-----
## About
Angel is a full-stack Web framework in Dart. It aims to
streamline development by providing many common features
out-of-the-box in a consistent manner.

With features like the following, Angel is the all-in-one framework you should choose to build your next project:
* GraphQL Support
* PostgreSQL ORM
* Dependency Injection
* Static File Handling
* And much more...

See all the packages in the `packages/` directory.

## IMPORTANT NOTES
This is a port of Angel Framework to work with Dart SDK 2.12.x and above. Dart SDK 2.12.x and below are not supported. 

Branch: master
- Same as sdk-2.12.x branch

Branch: sdk-2.12.x
- Required Dart SDK: ">=2.10.0 <3.0.0"
- NNBD Support: No
- Status: Production
- Notes: Not all packages are fully tested. Refer to WIKI page for details. The Basic and ORM boilerplates are working and can be found at https://github.com/dukefirehawk/boilerplates under "basic-sdk-2.12.x" and "orm-sdk-2.12.x" branch respectively. 

Branch: sdk-2.12.x_nnbd
- Required Dart SDK: ">=2.12.0 <3.0.0"
- NNBD Support: Yes
- Status: Development 
- Notes: Migration and code refactoring in progress. Refer to WIKI page for details.

Branch: sdk-2.10.x 
- Required Dart SDK: ">=2.10.0 <2.12.0"
- NNBD support: No
- Status: Retired
- Notes: Upgrade completed. Not all packages are fully tested. This branch is the baseline used in migrating the framework to Dart SDK 2.12.x. It may still work with Dart SDK 2.10.x but no longer maintained. 

## Installation & Setup

Once you have [Dart](https://www.dartlang.org/) installed, bootstrapping a project is as simple as running a few shell commands:

Install the [Angel CLI](https://github.com/dukefirehawk/cli):

```bash
pub global activate --source git https://github.com/dukefirehawk/cli.git
```

Bootstrap a project:

```bash
angel init hello
```

You can even have your server run and be *hot-reloaded* on file changes:

```bash
dart --observe bin/dev.dart
```

(For CLI development only)Install Angel CLI

```bash
pub global activate --source path ./packages/cli
```

Next, check out the [detailed documentation](https://docs.angel-dart.dev/v/2.x) to learn to flesh out your project.

## Examples and Documentation
Visit the [documentation](https://docs.angel-dart.dev/v/2.x)
for dozens of guides and resources, including video tutorials,
to get up and running as quickly as possible with Angel.

Examples and complete projects can be found
[here](https://github.com/angel-dart/examples-v2).


You can also view the [API Documentation](http://www.dartdocs.org/documentation/angel_framework/latest).

There is also an [Awesome Angel :fire:](https://github.com/angel-dart/awesome-angel) list.

## Contributing
Interested in contributing to Angel? Start by reading the contribution guide [here](CONTRIBUTING.md).
