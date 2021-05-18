# angel3_symbol_table
[![version](https://img.shields.io/badge/pub-v2.0.2-brightgreen)](https://pub.dartlang.org/packages/angel3_symbol_table)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/angel_dart/discussion)](https://gitter.im/angel_dart/discussion)

[![License](https://img.shields.io/github/license/dukefirehawk/angel)](https://github.com/dukefirehawk/angel/tree/angel3/packages/symbol_table/LICENSE)

A generic symbol table implementation in Dart, with support for scopes and constants.
The symbol tables produced by this package are hierarchical (in this case, tree-shaped),
and utilize basic memoization to speed up repeated lookups.

# Variables
To represent a symbol, use `Variable`. I opted for the name
`Variable` to avoid conflict with the Dart primitive `Symbol`.

```dart
var foo =  Variable<String>('foo');
var bar =  Variable<String>('bar', value: 'baz');

// Call `lock` to mark a symbol as immutable.
var shelley =  Variable<String>('foo', value: 'bar')..lock();

foo.value = 'bar';
shelley.value = 'Mary'; // Throws a StateError - constants cannot be overwritten.

foo.lock();
foo.value = 'baz'; // Also throws a StateError - Once a variable is locked, it cannot be overwritten.
```

## Visibility
Variables are *public* by default, but can also be marked as *private* or *protected*. This can be helpful if you are trying
to determine which symbols should be exported from a library or class.

```dart
myVariable.visibility = Visibility.protected;
myVariable.visibility = Visibility.private;
```

# Symbol Tables
It's easy to create a basic symbol table:

```dart
var mySymbolTable =  SymbolTable<int>();
var doubles =  SymbolTable<double>(values: {
  'hydrogen': 1.0,
  'avogadro': 6.022e23
});

// Create a new variable within the scope.
doubles.create('one');
doubles.create('one', value: 1.0);
doubles.create('one', value: 1.0, constant: true);

// Set a variable within an ancestor, OR create a new variable if none exists.
doubles.assign('two', 2.0);

// Completely remove a variable.
doubles.remove('two');

// Find a symbol, either in this symbol table or an ancestor.
var symbol = doubles.resolve('one');

// Find OR create a symbol.
var symbol = doubles.resolveOrCreate('one');
var symbol = doubles.resolveOrCreate('one', value: 1.0);
var symbol = doubles.resolveOrCreate('one', value: 1.0, constant: true);
```

# Exporting Symbols
Due to the tree structure of symbol tables, it is extremely easy to
extract a linear list of distinct variables, with variables lower in the hierarchy superseding their parents
(effectively accomplishing variable shadowing).

```dart
var allSymbols = mySymbolTable.allVariables;
```

We can also extract symbols which are *not* private. This helps us export symbols from libraries
or classes.

```dart
var exportedSymbols = mySymbolTable.allPublicVariables;
```

It's easy to extract symbols of a given visibility:
```dart
var exportedSymbols = mySymbolTable.allVariablesWithVisibility(Visibility.protected);
```

# Child Scopes
There are three ways to create a new symbol table:


## Regular Children
This is what most interpreters need; it simply creates a symbol table with the current symbol table
as its parent. The new scope can define its own symbols, which will only shadow the ancestors within the
correct scope.

```dart
var child = mySymbolTable.createChild();
var child = mySymbolTable.createChild(values: {...});
```

### Depth
Every symbol table has an associated `depth` attached to it, with the `depth` at the root
being `0`. When `createChild` is called, the resulting child has an incremented `depth`.

## Clones
This creates a scope at the same level as the current one, with all the same variables.

```dart
var clone = mySymbolTable.clone();
```

## Forked Scopes
If you are implementing a language with closure functions, you might consider looking into this.
A forked scope is a scope identical to the current one, but instead of merely copying references
to variables, the values of variables are copied into new ones.

The new scope is essentially a "frozen" version of the current one.

It is also effectively orphaned - though it is aware of its `parent`, the parent scope is unaware
that the forked scope is a child. Thus, calls to `resolve` may return old variables, if a parent
has called `remove` on a symbol.

```dart
var forked = mySymbolTable.fork();
var forked = mySymbolTable.fork(values: {...});
```

# Creating Names
In languages with block scope, oftentimes, identifiers will collide within a global scope.
To avoid this, symbol tables expose a `uniqueName()` method that simply attaches a numerical suffix to
an input name. The name is guaranteed to never be repeated within a specific scope.

```dart
var name0 = mySymbolTable.uniqueName('foo'); // foo0
var name1 = mySymbolTable.uniqueName('foo'); // foo1
var name2 = mySymbolTable.uniqueName('foo'); // foo2
```

# `this` Context
Many languages handle a sort of `this` context that values within a scope may
optionally be resolved against. Symbol tables can easily set their context
as follows:

```dart
void foo() {
  mySymbolTable.context = thisContext;
}
```

Resolution of the `context` getter functions just like a symbol; if none is
set locally, then it will refer to the parent.

```dart
void bar() {
  mySymbolTable.context = thisContext;
  expect(mySymbolTable.createChild().createChild().context, thisContext);
}
```