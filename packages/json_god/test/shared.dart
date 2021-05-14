import 'package:logging/logging.dart';
import 'package:angel3_json_god/angel3_json_god.dart';
import 'package:stack_trace/stack_trace.dart';

void printRecord(LogRecord rec) {
  print(rec);
  if (rec.error != null) print(rec.error);
  if (rec.stackTrace != null) print(Chain.forTrace(rec.stackTrace!).terse);
}

class SampleNestedClass {
  String? bar;

  SampleNestedClass([String? this.bar]);
}

class SampleClass {
  String? hello;
  List<SampleNestedClass> nested = [];

  SampleClass([String? this.hello]);
}

@WithSchemaUrl(
    "http://raw.githubusercontent.com/SchemaStore/schemastore/master/src/schemas/json/babelrc.json")
class BabelRc {
  List<String> presets;
  List<String> plugins;

  BabelRc(
      {List<String> this.presets: const [],
      List<String> this.plugins: const []});
}

@WithSchema(const {
  r"$schema": "http://json-schema.org/draft-04/schema#",
  "title": "Validated Sample Class",
  "description": "Sample schema for validation via JSON God",
  "type": "object",
  "hello": const {"description": "A friendly greeting.", "type": "string"},
  "nested": const {
    "description": "A list of NestedSampleClass items within this instance.",
    "type": "array",
    "items": const {
      "type": "object",
      "bar": const {"description": "Filler text", "type": "string"}
    }
  },
  "required": const ["hello", "nested"]
})
class ValidatedSampleClass {}
