import 'package:angel3_auth/angel3_auth.dart';
import 'package:angel3_framework/angel3_framework.dart';
import 'package:test/test.dart';

/// The middleware are tagged with what they require, which documents of the
/// API, as those of `angel3_openapi`, list.
void main() {
  test('requireAuthentication requires a bearer JWT, or is a 403', () {
    var requirement = SecurityRequirement.of(requireAuthentication<Map>())
        .single;
    expect(requirement.schemes, [SecurityScheme.bearer]);
    expect(requirement.status, 403);
  });

  test('forceBasicAuth requires a bearer JWT or Basic, or is a 401', () {
    var requirement = SecurityRequirement.of(forceBasicAuth<Map>()).single;
    expect(requirement.schemes, [SecurityScheme.bearer, SecurityScheme.basic]);
    expect(requirement.status, 401);
  });
}
