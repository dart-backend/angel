import 'package:angel3_symbol_table/angel3_symbol_table.dart';

void main(List<String> args) {
  //var mySymbolTable = SymbolTable<int>();
  var doubles =
      SymbolTable<double>(values: {'hydrogen': 1.0, 'avogadro': 6.022e23});

// Create a new variable within the scope.
  doubles.create('one');
  doubles.create('one', value: 1.0);
  doubles.create('one', value: 1.0, constant: true);

// Set a variable within an ancestor, OR create a new variable if none exists.
  doubles.assign('two', 2.0);

// Completely remove a variable.
  doubles.remove('two');

// Find a symbol, either in this symbol table or an ancestor.
  //var symbol1 = doubles.resolve('one');

// Find OR create a symbol.
  //var symbol2 = doubles.resolveOrCreate('one');
  //var symbol3 = doubles.resolveOrCreate('one', value: 1.0);
  //var symbol4 = doubles.resolveOrCreate('one', value: 1.0, constant: true);
}
