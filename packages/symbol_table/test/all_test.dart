import 'package:angel3_symbol_table/angel3_symbol_table.dart';
import 'package:test/test.dart';

void main() {
  late SymbolTable<int> scope;

  setUp(() {
    scope = SymbolTable<int>(values: {'one': 1});
  });

  test('starter values', () {
    expect(scope['one']?.value, 1);
  });

  test('add', () {
    var two = scope.create('two', value: 2);
    expect(two.value, 2);
    expect(two.isImmutable, isFalse);
  });

  test('put', () {
    var one = scope.resolve('one');
    var child = scope.createChild();
    var three = child.assign('one', 3);
    expect(three.value, 3);
    expect(three, one);
  });

  test('private', () {
    var three = scope.create('three', value: 3)
      ..visibility = Visibility.private;
    expect(scope.allVariables, contains(three));
    expect(
        scope.allVariablesWithVisibility(Visibility.private), contains(three));
    expect(scope.allPublicVariables, isNot(contains(three)));
  });

  test('protected', () {
    var three = scope.create('three', value: 3)
      ..visibility = Visibility.protected;
    expect(scope.allVariables, contains(three));
    expect(scope.allVariablesWithVisibility(Visibility.protected),
        contains(three));
    expect(scope.allPublicVariables, isNot(contains(three)));
  });

  test('constants', () {
    var two = scope.create('two', value: 2, constant: true);
    expect(two.value, 2);
    expect(two.isImmutable, isTrue);
    expect(() => scope['two'] = 3, throwsStateError);
  });

  test('lock', () {
    expect(scope['one']?.isImmutable, isFalse);
    scope['one']!.lock();
    expect(scope['one']?.isImmutable, isTrue);
    expect(() => scope['one'] = 2, throwsStateError);
  });

  test('child', () {
    expect(scope.createChild().createChild().resolve('one')!.value, 1);
  });

  test('clone', () {
    var child = scope.createChild();
    var clone = child.clone();
    expect(clone.resolve('one'), child.resolve('one'));
    expect(clone.parent, child.parent);
  });

  test('fork', () {
    var fork = scope.fork();
    scope.assign('three', 3);

    expect(scope.resolve('three'), isNotNull);
    expect(fork.resolve('three'), isNull);
  });

  test('remove', () {
    var one = scope.remove('one')!;
    expect(one.value, 1);

    expect(scope.resolve('one'), isNull);
  });

  test('root', () {
    expect(scope.isRoot, isTrue);
    expect(scope.root, scope);

    var child = scope
        .createChild()
        .createChild()
        .createChild()
        .createChild()
        .createChild()
        .createChild()
        .createChild();
    expect(child.isRoot, false);
    expect(child.root, scope);
  });

  test('visibility comparisons', () {
    expect([Visibility.private, Visibility.protected],
        everyElement(lessThan(Visibility.public)));
    expect(Visibility.private, lessThan(Visibility.protected));
    expect(Visibility.protected, greaterThan(Visibility.private));
    expect(Visibility.public, greaterThan(Visibility.private));
    expect(Visibility.public, greaterThan(Visibility.protected));
  });

  test('depth', () {
    expect(scope.depth, 0);
    expect(scope.clone().depth, 0);
    expect(scope.fork().depth, 0);
    expect(scope.createChild().depth, 1);
    expect(scope.createChild().createChild().depth, 2);
    expect(scope.createChild().createChild().createChild().depth, 3);
  });

  test('unique name', () {
    expect(scope.uniqueName('foo'), 'foo0');
    expect(scope.uniqueName('foo'), 'foo1');
    expect(scope.createChild().uniqueName('foo'), 'foo2');
    expect(scope.createChild().uniqueName('foo'), 'foo2');
    var child = scope.createChild();
    expect(child.uniqueName('foo'), 'foo2');
    expect(child.uniqueName('foo'), 'foo3');
    expect(child.createChild().uniqueName('foo'), 'foo4');
  });

  test('context', () {
    scope.context = 24;
    expect(scope.context, 24);
    expect(scope.createChild().context, 24);
    expect(scope.createChild().createChild().context, 24);

    var child = scope.createChild().createChild()..context = 35;
    expect(child.context, 35);
    expect(child.createChild().context, 35);
    expect(child.createChild().createChild().context, 35);
    expect(scope.context, 24);
  });
}
