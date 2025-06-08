# Angel3 ORM for PostgreSQL

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_orm_postgres?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Discord](https://img.shields.io/discord/1060322353214660698)](https://discord.gg/3X6bxTUdCM)
[![License](https://img.shields.io/github/license/dart-backend/angel)](https://github.com/dart-backend/angel/tree/master/packages/orm/angel_orm_postgres/LICENSE)

Angel3 ORM for working with PostgreSQL database 12 or later.

For documentation about the ORM, see [Developer Guide](https://angel3-docs.dukefirehawk.com/guides/orm)

## Migrating to 8.1.0 and above

`postgres` has been upgraded from 2.x.x to 3.x.x since version 8.1.0. This is a breaking change as `postgres` 3.x.x has revamped its API. Therefore when upgrading to 8.1.0 and beyond, the PostgreSQL connection settings need to be migrated. The rest should remain the same. Please see the example for the new PostgreSQL connection settings.

## Usage

1. Create a model, i.e. `car.dart`

   ```dart
    import 'package:angel3_migration/angel3_migration.dart';
    import 'package:angel3_orm/angel3_orm.dart';
    import 'package:angel3_serialize/angel3_serialize.dart';
    import 'package:optional/optional.dart';
    
    part 'car.g.dart';

    @serializable
    @orm
    class CarEntity extends Model {
        String? make;
        String? description;
        bool? familyFriendly;
        DateTime? recalledAt;
        double? price;
    }
   ```

2. Run the following command to generate the required `.g.dart` file for the model.

    ```bash
    dart run build_runner build
    ```

3. Write the query program. i.e. `CarPersistence.dart`

    ```dart
    import 'package:angel3_migration_runner/angel3_migration_runner.dart';
    import 'package:angel3_orm/angel3_orm.dart';
    import 'package:logging/logging.dart';
    import 'package:postgres/postgres.dart';
    import 'models/car.dart';

    void main() async {
    
        // Setup the connections
        final conn = await Connection.open(
            Endpoint(
                host: 'localhost',
                port: 5432,
                database: 'postgres',
                username: 'postgres',
                password: 'postgres'),
            settings: ConnectionSettings(sslMode: SslMode.disable));

        var executor = PostgreSqlExecutor(conn);

        // Create the `Car` table
        var runner = PostgresMigrationRunner(conn, migrations: [CarMigration()]);
        await runner.up();

        var query = CarQuery();
        query.values
            ..make = 'Ferrari'
            ..description = 'Vroom vroom!'
            ..price = 1200000.00
            ..familyFriendly = false;
        
        // insert a new record into the `cars` table
        var ferrari = (await query.insert(executor)).value;
    }
    ```
