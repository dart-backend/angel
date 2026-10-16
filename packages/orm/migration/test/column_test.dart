import 'package:angel3_migration/angel3_migration.dart';
import 'package:angel3_orm/angel3_orm.dart';
import 'package:test/test.dart';

/// Keeps the columns declared on it.
class _Table extends Table {
  final columns = <String, MigrationColumn>{};

  @override
  MigrationColumn declareColumn(String name, Column column) =>
      columns[name] = MigrationColumn.from(column);
}

void main() {
  group('MigrationColumn.from', () {
    test('keeps all the attributes of a column', () {
      var column = MigrationColumn.from(
        const Column(
          type: ColumnType.decimal,
          isNullable: false,
          name: 'price',
          length: 20,
          precision: 10,
          scale: 2,
          timezone: 'UTC',
          expression: 'cost * 2',
          indexType: IndexType.unique,
          defaultValue: 0,
        ),
      );

      expect(column.type, same(ColumnType.decimal));
      expect(column.isNullable, isFalse);
      expect(column.name, 'price');
      expect(column.length, 20);
      expect(column.precision, 10);
      expect(column.scale, 2);
      expect(column.timezone, 'UTC');
      expect(column.expression, 'cost * 2');
      expect(column.indexType, IndexType.unique);
      expect(column.defaultValue, 0);
    });

    test('returns a MigrationColumn as it is', () {
      var column = MigrationColumn(ColumnType.int);
      expect(MigrationColumn.from(column), same(column));
    });
  });

  group('precision and scale', () {
    test('are kept by numeric and decimal', () {
      var table = _Table()
        ..numeric('a', precision: 10, scale: 2)
        ..decimal('b', precision: 12, scale: 0);

      expect(table.columns['a']!.type, same(ColumnType.numeric));
      expect(
        [table.columns['a']!.precision, table.columns['a']!.scale],
        [10, 2],
      );
      expect(table.columns['b']!.type, same(ColumnType.decimal));
      expect(
        [table.columns['b']!.precision, table.columns['b']!.scale],
        [12, 0],
      );
    });

    test('default to those of Column', () {
      var column = (_Table()..decimal('a')).columns['a']!;
      expect(column.precision, Column.defaultPrecision);
      expect(column.scale, Column.defaultScale);
    });

    test('a scale greater than the precision is rejected', () {
      expect(
        () => _Table().numeric('a', precision: 5, scale: 10),
        throwsArgumentError,
      );
      expect(
        () => MigrationColumn.from(
          const Column(type: ColumnType.decimal, precision: 5, scale: 6),
        ),
        throwsArgumentError,
      );
    });

    test('a precision below 1 or a negative scale is rejected', () {
      expect(
        () => _Table().decimal('a', precision: 0, scale: 0),
        throwsArgumentError,
      );
      expect(() => _Table().decimal('a', scale: -1), throwsArgumentError);
    });

    test('are not checked for a type without them', () {
      // `Column`'s defaults (17, 3) are always there, and unused.
      var column = MigrationColumn(ColumnType.int, precision: 0, scale: 5);
      expect(column.type, same(ColumnType.int));
    });
  });

  test('varChar keeps its length', () {
    var column = (_Table()..varChar('a', length: 40)).columns['a']!;
    expect(column.type, same(ColumnType.varChar));
    expect(column.length, 40);
  });
}
