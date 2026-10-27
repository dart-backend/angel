# Angel3 Container Generator

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_container_generator?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/container/container_generator/LICENSE)

Generates the reflection data that `package:angel3_container` and Angel3 need, so dependency injection, `@Expose` controllers and `@Hooks`/`@Middleware` annotations work **without `dart:mirrors`**, including in AOT-compiled apps (`dart compile exe`), obfuscated or not.

## Installation

In your `pubspec.yaml`:

```yaml
dependencies:
  angel3_container: ^10.0.0
dev_dependencies:
  angel3_container_generator: ^10.0.0
  build_runner: ^2.4.0
```

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

With Angel3, pass the reflector to the app: `Angel(reflector: StaticReflector.combine([...]))`. Mark with `@injectable`:

* Controllers, so their `@Expose` methods are routed (see `example/controller.dart`), and services with `@Hooks` or `@Middleware`. The generated data lists each class's annotations and the public instance methods it declares, with their parameters (including annotations such as `@Query`) and annotations.
* Models whose members are read by name, as in a Jael template with `angel3_jael`: the generated data reads each class's public instance fields, getters and methods, declared or inherited, through `StaticReflectedInstance.getField`, which throws a `ReflectionException` for any other name.
* Top-level functions used as handlers, so `@Middleware` on them applies and `ioc(handler)` can inject their parameters.

The generated code calls each class's unnamed constructor without `dart:mirrors`. A constructor with optional parameters is called with `Function.apply` and symbol literals (which keep working when the app is obfuscated), passing only the arguments the container resolved, so every other parameter keeps its default value, including a default inherited through `super.x`. `this.x`/`super.x` parameters and import prefixes are supported.

## Limitations

* Only the unnamed constructor is used. An abstract class can be constructed only through a `factory` unnamed constructor.
* Generic and private classes are not supported.
* The library must import `package:angel3_container/angel3_container.dart` without a prefix, as the generated code uses its names.
* A parameter type the library cannot name (for example a `super.x` parameter whose type only the superclass's library imports) fails the build with an error; import that type, or declare the parameter's type.
* Closures cannot be described, so `ioc((Foo foo) => ...)` needs an explicit `injection:` (or a named, `@injectable` top-level function).
* Only the methods a class declares are listed (as `MirrorsReflector` lists a controller's), so `@Hooks` or `@Middleware` on a service method that the class inherits without overriding is not seen; `MirrorsReflector` does see it. To use one, override the method in the class and annotate the override.
* Annotations are copied from the source. One that names a static member of its class without the class name is qualified with it; other names must be in scope in the library, as they are for the annotation itself.

## Development

The output for `test/fixtures` and `example` is checked in. Regenerate it with `dart run build_runner build` after changing them or the generator.

## Migrating from 9.x to 10.0.0

The breaking changes of each release are listed in the [CHANGELOG](CHANGELOG.md). Those of 10.0.0 that may need changes in an app:

The generator is rewritten: it generates reflection data for `@injectable` classes and top-level functions, used through `StaticReflector`, and no longer depends on `reflectable`. `GeneratedReflector`, `ContainedReflectable` and `contained` are removed. To migrate:

1. Replace `@contained` with `@injectable`, from `package:angel3_container/angel3_container.dart`, and add `part '<file>.g.dart';` to each library with such classes.
2. Replace `reflectable_builder` with `angel3_container_generator` and `build_runner` in `dev_dependencies`, and run `dart run build_runner build`.
3. Replace `GeneratedReflector()` with `StaticReflector.combine([...])`, passing each library's generated variable:

   ```dart
   // 9.x
   var app = Angel(reflector: GeneratedReflector());

   // 10.0.0, with the data of services.dart and controllers.dart
   var app = Angel(
     reflector: StaticReflector.combine([servicesReflection, controllersReflection]),
   );
   ```

Closures cannot be described, so `ioc` on a closure needs an explicit `injection:`, or a named, `@injectable` top-level function.
