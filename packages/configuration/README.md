# Angel3 Configuration Loader

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_configuration?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/configuration/LICENSE)

Automatic YAML configuration loader for [Angel3 framework](https://pub.dev/packages/angel3)

## About

Any web app needs different configuration for development and production. This plugin will search
for a `config/default.yaml` file. If it is found, configuration from it is loaded into `app.configuration`.
Then, it will look for a `config/$ANGEL_ENV` file. (i.e. config/development.yaml). If this found, all of its
configuration be loaded, and will override anything loaded from the `default.yaml` file. This allows for your
app to work under different conditions without you re-coding anything. :)

## Installation

In `pubspec.yaml`:

```yaml
dependencies:
    angel3_configuration: ^6.0.0
```

## Usage

Example Configuration

```yaml
# Define normal YAML objects
some_key: foo
this_is_a_map:
  a_string: "string"
  another_string: "string"
  
```

You can also load configuration from the environment:

```yaml
# Loaded from the environment
system_path: $PATH
```

If a `.env` file is present in your configuration directory (i.e. `config/.env`), then it will be loaded before
applying YAML configuration.

You can also include values from one file into another:

```yaml
_include:
  - "./include-prod.yaml"
  - "./include-misc.yaml"
_include: "just-one-file.yaml"
```

**Server-side**
Call `configuration()`. The loaded configuration will be available in your application's `configuration` map.

`configuration` also accepts a `sourceDirectory` or `overrideEnvironmentName` parameter.
The former will allow you to search in a directory other than `config`, and the latter lets you
override `$ANGEL_ENV` by specifying a specific configuration name to look for (i.e. `production`).

This package uses [`package:angel3_merge_map`](https://pub.dev/packages/angel3_merge_map)
internally, so existing configurations can be deeply merged.

Example:

```yaml
# default.yaml
foo:
  bar: baz
  quux: hello
  
# production.yaml
foo:
  quux: goodbye
  yellow: submarine
  
# Propagates to:
foo:
  bar: baz
  quux: goodbye
  yellow: submarine
```
