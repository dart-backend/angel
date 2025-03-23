abstract class Dialect {
  bool get cteSupport;

  bool get writableCteSupport;
}

class MySQLDialect implements Dialect {
  const MySQLDialect();

  @override
  bool get cteSupport => true;

  @override
  bool get writableCteSupport => false;
}

class PostgreSQLDialect implements Dialect {
  const PostgreSQLDialect();

  @override
  bool get cteSupport => true;

  @override
  bool get writableCteSupport => true;
}
