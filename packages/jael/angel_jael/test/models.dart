import 'package:angel3_container/angel3_container.dart';
import 'package:angel3_framework/angel3_framework.dart';

part 'models.g.dart';

/// A model whose members a template reads through the reflection data
/// generated for it (regenerate it with `dart run build_runner build`).
@injectable
class Repo extends Model {
  final String name;
  final int stars;

  Repo(this.name, this.stars, {super.id});

  bool get popular => stars >= 100;
}
