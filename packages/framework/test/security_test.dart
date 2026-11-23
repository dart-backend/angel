import 'package:angel3_framework/angel3_framework.dart';
import 'package:test/test.dart';

void main() {
  test('a handler tagged with a requirement has it', () {
    const requirement = SecurityRequirement([
      SecurityScheme.bearer,
    ], status: 403);
    RequestHandler handler = requirement.tag(
      (RequestContext req, ResponseContext res) => true,
    );
    expect(SecurityRequirement.of(handler), [same(requirement)]);
    expect(
      SecurityRequirement.of((RequestContext req, ResponseContext res) => true),
      isEmpty,
    );
    expect(requirement.status, 403);
    expect(SecurityScheme.bearer.definition['scheme'], 'bearer');
  });

  test('chain has the requirements of its handlers', () {
    const bearer = SecurityRequirement([SecurityScheme.bearer]);
    const basic = SecurityRequirement([SecurityScheme.basic]);
    RequestHandler a = bearer.tag((req, res) => true);
    RequestHandler b = basic.tag((req, res) => true);
    expect(SecurityRequirement.of(chain([a, (req, res) => true, b])), [
      same(bearer),
      same(basic),
    ]);
    expect(SecurityRequirement.of(chain([(req, res) => true])), isEmpty);
  });
}
