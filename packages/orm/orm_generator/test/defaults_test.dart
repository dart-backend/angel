import 'package:angel3_orm_generator/angel3_orm_generator.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:test/test.dart';

/// The errors, and the generated migration, of the model [source].
Future<(List<String>, String)> migrationOf(String source) async {
  var readerWriter = TestReaderWriter(rootPackage: 'a');
  await readerWriter.testing.loadIsolateSources();
  var errors = <String>[];
  await testBuilder(
    migrationBuilder(BuilderOptions.empty),
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
    '.dart_tool/build/generated/a/lib/model.angel3_migration.g.part',
  );
  return (
    errors,
    readerWriter.testing.exists(output)
        ? readerWriter.testing.readString(output)
        : '',
  );
}

void main() {
  test('a RawSql default of a @Column is SQL, as currentTimestamp', () async {
    var (errors, migration) = await migrationOf('''
@serializable
@orm
abstract class EventEntity extends Model {
  @Column(defaultValue: currentTimestamp)
  DateTime? get seenAt;

  @Column(defaultValue: RawSql("lower('A')"))
  String? get code;

  @Column(defaultValue: 'plain')
  String? get label;
}
''');
    expect(errors, isEmpty);
    expect(
      migration,
      contains(
        "timeStamp('seen_at').defaultsTo(const RawSql('CURRENT_TIMESTAMP'))",
      ),
    );
    expect(migration, contains(r".defaultsTo(const RawSql('lower(\'A\')'))"));
    expect(migration, contains("defaultsTo('plain')"));
  });

  group('a RawSql default of a primary key is refused', () {
    for (var (kind, field) in [
      (
        'the UUID id of a Model',
        '''
  @override
  @Column(type: ColumnType.uuid, indexType: IndexType.primaryKey,
      defaultValue: RawSql('gen_random_uuid()'))
  String? get id;''',
      ),
      (
        'a primary key of a @Column',
        '''
  @Column(type: ColumnType.varChar, indexType: IndexType.primaryKey,
      defaultValue: RawSql('uuid()'))
  String? get code;''',
      ),
      (
        'of @SerializableField',
        '''
  @override
  @Column(type: ColumnType.uuid, indexType: IndexType.primaryKey)
  @SerializableField(defaultValue: RawSql('gen_random_uuid()'))
  String? get id;''',
      ),
    ]) {
      test(kind, () async {
        var (errors, migration) = await migrationOf('''
@serializable
@orm
abstract class KeyEntity extends Model {
$field
}
''');
        expect(errors, [
          allOf(
            contains('has a default of SQL'),
            contains('is not supported'),
            contains('String primary keys'),
          ),
        ]);
        expect(migration, isEmpty);
      });
    }
  });

  test('another object is an error that names the field', () async {
    var (errors, _) = await migrationOf('''
class Point {
  const Point();
}

@serializable
@orm
abstract class PlaceEntity extends Model {
  @Column(defaultValue: Point())
  String? get spot;
}
''');
    expect(errors, [
      allOf(contains('PlaceEntity.spot'), contains('give a bool')),
    ]);
  });
}
