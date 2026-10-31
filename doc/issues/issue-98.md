# Issue 98

Consider the following classes:

/// Enumeration class requiring custom (de)serialization
/// We want it to be persisted as 'R', 'G', 'B' instead of 0, 1, 2
enum Color {
  red('R'),
  green('G'),
  blue('B');
  final String code;
  const Color(this.code);
}

/// The class containing the custom (de)serializable enum
@orm
@serializable
abstract class _HasCar extends Model {
  // ...

  /// Our enum field with custom (de)serializers
  @SerializableField(
    serializesTo: String,
    serializer: #colorToCode,
    deserializer: #codeToColor,
  )
  Color? color;
}

/// The deserializer method
Color? codeToColor(String? code) => code == null
    ? null
    : Color.values.firstWhere((color) => color.code == code);

/// The serializer method
String? colorToCode(Color? color) => color?.code;

Currently, the generated HasCarQuery class will have a parseRow method that looks something like this:

  Optional<HasCar> parseRow(List row) {
    ...
    var model = HasCar(
      ...
      color: fields.contains('color')
          ? row[3] == null
              ? null
              : Color.values[(row[3] as int)]  // <- results in type cast exception
          : null,
      ...
    );
    return Optional.of(model);
  }

The generated HasCarSerializer will (de)serialize using the defined colorToCode(model.color) and codeToColor(map['color']) methods. This results in the value being persisted in the databse as a String, but since the enum handler just assumes that the indeces are being persisted, it will try to read that value as an int, resulting in a type cast exception.

Therefore, I'd like to propose that the OrmGenerator will also take the following @SerializableField properties into account:

    serializer
    deserializer
    serializesTo

Any thoughts on this? I'll submit a PR as soon as possible...
