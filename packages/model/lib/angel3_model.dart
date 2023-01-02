/// Represents a generic data model with an ID and timestamps.
class Model {
  /// A unique identifier corresponding to this item.
  String? id;

  /// The time at which this item was created.
  DateTime? createdAt;

  /// The last time at which this item was updated.
  DateTime? updatedAt;

  Model({this.id, this.createdAt, this.updatedAt});

  /// Returns the [id], parsed as an [int].
  int get idAsInt => id != null ? int.tryParse(id ?? "-1") ?? -1 : -1;

  /// Returns the [id] or "" if null.
  String get idAsString => id ?? "";
}

/// Represents a generic data model with audit log feature.
class AuditableModel extends Model {
  /// The authorized user who created the record.
  String? createdBy;

  /// The user who updated the record last time.
  String? updatedBy;

  AuditableModel(
      {super.id,
      super.createdAt,
      this.createdBy,
      super.updatedAt,
      this.updatedBy});
}
