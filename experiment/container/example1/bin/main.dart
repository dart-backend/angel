import 'dart:mirrors';

void main() {
  final stopwatch = Stopwatch()..start();

  var reflectedClass = reflect(Shape());

  reflectedClass.invoke(#draw, []);

  //reflectedClass.invoke(Symbol('draw'), []);

  print('Reflection executed in ${stopwatch.elapsed.inMilliseconds} ms');
  stopwatch.stop();

  printAnnotationValue(String);
  printAnnotationValue(Shape);
}

class Shape {
  void draw() => print("Draw Shape");
}

void printAnnotationValue(final Type clazz) {
  final DeclarationMirror clazzDeclaration = reflectClass(clazz);
  final ClassMirror someAnnotationMirror = reflectClass(Shape);
  final annotationInstsanceMirror =
      clazzDeclaration.metadata.where((d) => d.type == someAnnotationMirror);
  if (annotationInstsanceMirror.isEmpty) {
    print('Annotation is not on this class');
    return;
  }
  final someAnnotationInstance =
      (annotationInstsanceMirror.first.reflectee as Shape);
  print("${someAnnotationInstance.draw}");
}
