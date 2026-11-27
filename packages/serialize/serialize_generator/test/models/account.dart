import 'package:angel3_serialize/angel3_serialize.dart';
part 'account.g.dart';

/// A model with a constructor of its own (issue 171): a positional
/// parameter of no field, and named parameters of fields and of none.
@serializable
abstract class AccountEntity {
  AccountEntity(this.region, {required this.owner, int tier = 1, this.note})
    : level = tier * 10;

  /// Not a field of the model: it has no setter.
  final String region;

  /// Not a field of the model either.
  final int level;

  String owner;

  String? note;

  String? get email;
}
