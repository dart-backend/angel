import 'package:angel_http_exception/angel_http_exception.dart';

void main() =>
    throw AngelHttpException.notFound(message: "Can't find that page!");
