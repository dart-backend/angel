/// A annotation for components that source-gen their `render()` methods.
class Jael {
  /// The raw template.
  final String? template;

  /// The path to a [template].
  final String? templateUrl;

  /// Whether to parse the [template] as `DSX`.
  final bool? asDsx;

  const Jael({this.template, this.templateUrl, this.asDsx});
}

/// Shorthand for enabling `DSX` syntax when using a [Jael] annotation.
class Dsx extends Jael {
  const Dsx({super.template, super.templateUrl}) : super(asDsx: true);
}
