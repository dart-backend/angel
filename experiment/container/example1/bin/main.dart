import 'dart:mirrors';
import 'package:example1/src/models.dart';

void main() {
  final stopwatch = Stopwatch()..start();

  var reflectedClass = reflect(Shape());

  reflectedClass.invoke(#draw, []);

  //reflectedClass.invoke(Symbol('draw'), []);

  print('Reflection executed in ${stopwatch.elapsed.inMilliseconds} ms');
  stopwatch.stop();

  printAnnotationValue(String);
  printAnnotationValue(Shape);
  printAnnotationValue(Square);
}

class Shape {
  void draw() => print("Draw Shape");
}

@Person('Will', 'Tom')
class Square {
  void greetHii() {
    print("Hii Welcome to flutter agency");
  }
}

void printAnnotationValue(final Type clazz) {
  final DeclarationMirror clazzDeclaration = reflectClass(clazz);
  final ClassMirror someAnnotationMirror = reflectClass(Person);
  final annotationInstsanceMirror =
      clazzDeclaration.metadata.where((d) => d.type == someAnnotationMirror);
  if (annotationInstsanceMirror.isEmpty) {
    print('No annotated class found');
    return;
  }
  final someAnnotationInstance =
      (annotationInstsanceMirror.first.reflectee as Person);
  print(someAnnotationInstance.firstName);
}
