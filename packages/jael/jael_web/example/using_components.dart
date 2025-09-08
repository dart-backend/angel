import 'package:jael3_web/jael3_web.dart';
part 'using_components.g.dart';

@Jael(
  template: '''
<div>
  <h1>Welcome to my app</h1>
  <LabeledInput name="username" />
</div>
''',
)
class MyApp extends Component with _MyAppJaelTemplate {}

@Jael(
  template: '''
<div>
  <label>
    <b>{{name}}:</b>
  </label>
  <br>
  <input name=name placeholder="Enter " + name + "..." type="text">
</div>
''',
)
class LabeledInput extends Component with _LabeledInputJaelTemplate {
  @override
  final String? name;

  LabeledInput({this.name});
}
