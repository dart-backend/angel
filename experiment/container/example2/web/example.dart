import 'package:angel3_container_generator/angel3_container_generator.dart';
import 'package:angel3_framework/angel3_framework.dart';

@Expose('/hr')
class HrController extends Controller {
  @Expose('/')
  landingPage() => "Hello, world!";
}

@contained
class SalesController extends Controller {
  
  landingPage() => "Hello, world!";
}
