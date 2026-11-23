# Issue 118

Non-orm serializable jsonb column, can't run migration.

When using a non-orm `seriNon-orm serializable jsonb column, can't run migration.alizable` as a column, source_gen triggers a warning that leads to migration fail:

```dart
// simplified example
@orm
@serializable
abstract class _User extends Model {
  String get name;
  _Profile? get profile;
}

@serializable
abstract class _Profile {
  String get firstName;
  String get lastName;
}
```

Running build_runner succeeds with the following warning:

```bash
[INFO] ------------------------------------------------------------------------
[INFO] Starting Build
[INFO] Updating asset graph completed, took 2ms
[WARNING] angel3_orm_generator:angel3_orm on lib/src/models/models.dart:
Cannot generate ORM code for field profile of type _Profile?
[INFO] Running build completed, took 1.8s
[INFO] Caching finalized dependency graph completed, took 40ms
[INFO] Succeeded after 1.9s with 2 outputs (2 actions)
```

And then when I try to run `dart bin/migrate.dart up`  I get the following error:

```bash
../core/lib/src/models/models.g.dart:1020:7: Error: The getter 'profile' isn't defined for the class 'UserQueryWhere'.
 - 'UserQueryWhere' is from 'package:core/src/models/models.dart' ('../core/lib/src/models/models.dart').
Try correcting the name to the name of an existing getter, or defining a getter or field named 'profile'.
      profile,
      ^^^^^^^
```

What am I missing here? The point is to use a serializable class for a jsonb column, but the generator seems to want to be able to query using that jsonb field. Any hints to what I'm doing wrong would be really appreciated. Thanks.
