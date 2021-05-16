import 'package:angel3_http_exception/angel3_http_exception.dart';

void main() =>
    throw AngelHttpException.notFound(message: "Can't find that page!");
