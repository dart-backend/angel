final Map<Symbol, String> _cache = {};

String fastNameFromSymbol(Symbol s) {
  return _cache.putIfAbsent(s, () {
    var str = s.toString();
    var open = str.indexOf('"');
    var close = str.lastIndexOf('"');
    return str.substring(open + 1, close);
  });
}
