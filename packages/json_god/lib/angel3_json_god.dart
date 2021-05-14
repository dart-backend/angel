/// A robust library for JSON serialization and deserialization.
library angel3_json_god;

//import 'package:dart2_constant/convert.dart';
import 'dart:convert';
import 'package:logging/logging.dart';
import 'src/reflection.dart' as reflection;

part 'src/serialize.dart';
part 'src/deserialize.dart';
part 'src/validation.dart';
part 'src/util.dart';

/// Instead, listen to [logger].
@deprecated
bool debug = false;

final Logger logger = Logger('json_god');
