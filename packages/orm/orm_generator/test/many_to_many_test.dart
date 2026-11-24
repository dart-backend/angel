import 'package:angel3_orm_generator/angel3_orm_generator.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:test/test.dart';

/// The errors, and the generated queries, of the models [source].
Future<(List<String>, String)> queriesOf(String source) async {
  var readerWriter = TestReaderWriter(rootPackage: 'a');
  await readerWriter.testing.loadIsolateSources();
  var errors = <String>[];
  await testBuilder(
    ormBuilder(BuilderOptions.empty),
    {
      'a|lib/model.dart':
          '''
import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:angel3_serialize/angel3_serialize.dart';
part 'model.g.dart';
$source
''',
    },
    rootPackage: 'a',
    readerWriter: readerWriter,
    onLog: (log) {
      if (log.level.value >= 1000) errors.add('${log.message} ${log.error}');
    },
  );
  var output = AssetId(
    'a',
    '.dart_tool/build/generated/a/lib/model.angel3_orm.g.part',
  );
  return (
    errors,
    readerWriter.testing.exists(output)
        ? readerWriter.testing.readString(output)
        : '',
  );
}

/// The `Query.pivotKeys` call of the many-to-many [field]: its table, and
/// the columns from and to.
List<String> pivotOf(String queries, String field) {
  var call = RegExp(
    "var ${field}Pivot = [^;]*?Query\\.pivotKeys\\(\\s*executor,\\s*"
    "'([^']+)',\\s*'([^']+)',\\s*'([^']+)'",
  ).firstMatch(queries);
  expect(call, isNotNull, reason: 'no pivot of $field');
  return [call!.group(1)!, call.group(2)!, call.group(3)!];
}

const membersAndBadges = '''
@serializable
@orm
abstract class MemberEntity extends Model {
  @ManyToMany(MemberBadgeEntity)
  List<BadgeEntity> get badges;
}

@serializable
@orm
abstract class BadgeEntity extends Model {
  @ManyToMany(MemberBadgeEntity)
  List<MemberEntity> get members;
}
''';

void main() {
  test('the columns are those of the pivot, of fields of any name', () async {
    var (errors, queries) = await queriesOf('''
$membersAndBadges
@serializable
@orm
abstract class MemberBadgeEntity {
  @belongsTo
  MemberEntity? get owner;

  @belongsTo
  BadgeEntity? get award;
}
''');
    expect(errors, isEmpty);
    // Not member_id and badge_id, of the class names.
    expect(pivotOf(queries, 'badges'), [
      'member_badges',
      'owner_id',
      'award_id',
    ]);
    expect(pivotOf(queries, 'members'), [
      'member_badges',
      'award_id',
      'owner_id',
    ]);
  });

  const friends = '''
@serializable
@orm
abstract class PersonEntity extends Model {
  @ManyToMany(FriendshipEntity, KEY)
  List<PersonEntity> get friends;
}

@serializable
@orm
abstract class FriendshipEntity {
  @belongsTo
  PersonEntity? get person;

  @belongsTo
  PersonEntity? get friend;
}
''';

  test(
    'of a pivot of a model and itself, the foreignKey is required',
    () async {
      var (errors, _) = await queriesOf(friends.replaceFirst(', KEY', ''));
      expect(errors, [
        allOf(
          contains('PersonEntity.friends'),
          contains('several columns'),
          contains("foreignKey: 'person_id'"),
        ),
      ]);
    },
  );

  test(
    'of a pivot of a model and itself, the other is that of the foreignKey',
    () async {
      var (errors, queries) = await queriesOf(
        friends.replaceFirst('KEY', "foreignKey: 'person_id'"),
      );
      expect(errors, isEmpty);
      expect(pivotOf(queries, 'friends'), [
        'friendships',
        'person_id',
        'friend_id',
      ]);
    },
  );

  test('a foreignKey that is no column of the pivot is an error', () async {
    var (errors, _) = await queriesOf(
      friends.replaceFirst('KEY', "foreignKey: 'buddy_id'"),
    );
    expect(errors, [
      allOf(
        contains('"buddy_id"'),
        contains('no column'),
        contains('person_id'),
      ),
    ]);
  });

  test('a pivot of no @BelongsTo of the model is an error', () async {
    var (errors, _) = await queriesOf('''
$membersAndBadges
@serializable
@orm
abstract class MemberBadgeEntity {
  @belongsTo
  BadgeEntity? get award;
}
''');
    expect(
      errors,
      contains(
        allOf(contains('MemberEntity.badges'), contains('no @BelongsTo')),
      ),
    );
  });
}
