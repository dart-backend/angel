import 'dart:math';
import 'package:angel_framework/angel_framework.dart';
import 'package:faker/faker.dart';
export 'package:faker/faker.dart';

/// Generates data using a [Faker].
typedef FakerCallback = Function(Faker faker);

/// Used to seed nested objects.
typedef SeederCallback<T> = Function(T created,
    Function(Pattern path, SeederConfiguration configuration, {bool? verbose}));

/// Seeds the given service in development.
AngelConfigurer seed<T>(
  Pattern servicePath,
  SeederConfiguration<T> configuration, {
  bool verbose = false,
}) {
  return (Angel app) async {
    if (configuration.runInProduction != true) return;

    if (!app.services.containsKey(servicePath)) {
      throw ArgumentError(
          "App does not contain a service at path '$servicePath'.");
    }

    if (configuration.disabled == true) {
      print("Service '$servicePath' will not be seeded.");
      return;
    }

    var service = app.findService(servicePath);
    var faker = Faker();

    Map _buildTemplate(Map data) {
      return data.keys.fold({}, (map, key) {
        var value = data[key];

        if (value is FakerCallback) {
          return map..[key] = value(faker);
        } else if (value is Function) {
          return map..[key] = value();
        } else if (value is Map) {
          return map..[key] = _buildTemplate(value);
        } else {
          return map..[key] = value;
        }
      });
    }

    Future<Null> Function(SeederConfiguration configuration) _buildSeeder(
        Service? service,
        {bool? verbose}) {
      return (SeederConfiguration configuration) async {
        if (configuration.delete == true) await service!.remove(null);

        var count = configuration.count;
        var rnd = Random();
        if (count < 1) count = 1;

        for (var i = 0; i < count; i++) {
          Future _gen(template) async {
            var data = template;

            if (data is Map) {
              data = _buildTemplate(data);
            } else if (data is Faker) {
              data = template(faker);
            }

            var params = <String, dynamic>{}..addAll(configuration.params);
            var result = await service!.create(data, params);

            if (configuration.callback != null) {
              await configuration.callback!(result,
                  (Pattern path, SeederConfiguration configuration,
                      {bool? verbose}) {
                return _buildSeeder(app.findService(path),
                    verbose: verbose == true)(configuration);
              });
            }
          }

          if (configuration.template != null) {
            await _gen(configuration.template);
          } else if (configuration.templates.isNotEmpty == true) {
            var template = configuration.templates
                .elementAt(rnd.nextInt(configuration.templates.length));
            await _gen(template);
          } else {
            throw ArgumentError(
                'Configuration for service \'$servicePath\' must define at least one template.');
          }
        }

        if (verbose == true) {
          print('Created $count object(s) in service \'$servicePath\'.');
        }
      };
    }

    await _buildSeeder(service, verbose: verbose == true)(configuration);
  };
}

/// Configures the seeder.
class SeederConfiguration<T> {
  /// Optional callback on creation.
  final SeederCallback<T>? callback;

  /// Number of objects to seed.
  final int count;

  /// If `true`, all records in the service are deleted before seeding.
  final bool delete;

  /// If `true`, seeding will not occur.
  final bool disabled;

  /// Optional service parameters to be passed.
  final Map<String, dynamic> params;

  /// Unless this is `true`, the seeder will not run in production.
  final bool runInProduction;

  /// A data template to build from.
  final template;

  /// A set of templates to choose from.
  final Iterable templates;

  SeederConfiguration(
      {this.callback,
      this.count = 1,
      this.delete = true,
      this.disabled = false,
      this.params = const {},
      this.runInProduction = false,
      this.template,
      this.templates = const []});
}
