# Angel3 Container Builder

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_container_generator?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/container/container_generator/LICENSE)

Generates the reflection data that `package:angel3_container` needs to construct classes, so `Container.make` works **without `dart:mirrors`**, including in AOT-compiled apps (`dart compile exe`).

## Usage

1. Add `angel3_container` to `dependencies`, and `angel3_container_generator` and `build_runner` to `dev_dependencies`.
2. Annotate the classes the container should construct with `@injectable`, and add a `part` directive:

    ```dart
    import 'package:angel3_container/angel3_container.dart';

    part 'services.g.dart';

    @injectable
    class Greeter {
      final Config config;
      Greeter(this.config, {Logger? log});
    }
    ```

3. Run `dart run build_runner build`. Each library gets one variable named after its file, here `servicesReflection`.
4. Build the container's reflector from the generated data:

    ```dart
    var container = Container(StaticReflector.combine([servicesReflection]));
    var greeter = container.make<Greeter>();
    ```

With Angel3, pass the reflector to the app: `Angel(reflector: StaticReflector.combine([...]))`.

The generated code calls each class's unnamed constructor without `dart:mirrors`. A constructor with optional parameters is called with `Function.apply` and symbol literals (which keep working when the app is obfuscated), passing only the arguments the container resolved, so every other parameter keeps its default value, including a default inherited through `super.x`. `this.x`/`super.x` parameters and import prefixes are supported.

## Limitations

* Only the unnamed constructor is used. An abstract class can be constructed only through a `factory` unnamed constructor.
* Generic and private classes are not supported.
* The library must import `package:angel3_container/angel3_container.dart` without a prefix, as the generated code uses its names.
* A parameter type the library cannot name (for example a `super.x` parameter whose type only the superclass's library imports) fails the build with an error; import that type, or declare the parameter's type.
* This covers `Container.make` only. Request handler injection (`ioc`), `@Expose` controllers and `@Hooks`/`@Middleware` metadata still need `MirrorsReflector`, or an explicit `injection:` for `ioc`.

## Development

The output for `test/fixtures` and `example` is checked in. Regenerate it with `dart run build_runner build` after changing them or the generator.
