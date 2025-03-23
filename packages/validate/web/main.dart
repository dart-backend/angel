import 'dart:html';

import 'package:angel3_validate/angel3_validate.dart';

final $errors = querySelector('#errors') as UListElement?;
final $form = querySelector('#form') as FormElement?;
final $blank = querySelector('[name="blank"]') as InputElement?;

final Validator formSchema = Validator({
  'firstName*': [isString, isNotEmpty],
  'lastName*': [isString, isNotEmpty],
  'age*': [isInt, greaterThanOrEqualTo(18)],
  'familySize': [isInt, greaterThanOrEqualTo(1)],
  'blank!': []
}, defaultValues: {
  'familySize': 1
}, customErrorMessages: {
  'age': (age) {
    if (age is int && age < 18) {
      return 'Only adults can register for passports. Sorry, kid!';
    } else if (age == null || (age is String && age.trim().isEmpty)) {
      return 'Age is required.';
    } else {
      return 'Age must be a positive integer. Unless you are a monster...';
    }
  },
  'blank':
      "I told you to leave that field blank, but instead you typed '{{value}}'..."
});

void main() {
  $form!.onSubmit.listen((e) {
    e.preventDefault();
    $errors!.children.clear();

    var formData = {};

    for (var key in ['firstName', 'lastName', 'age', 'familySize']) {
      formData[key] = (querySelector('[name="$key"]') as InputElement).value;
    }

    if ($blank!.value!.isNotEmpty) formData['blank'] = $blank!.value;

    print('Form data: $formData');

    try {
      var passportInfo =
          formSchema.enforceParsed(formData, ['age', 'familySize']);

      $errors!.children
        ..add(success('Successfully registered for a passport.'))
        ..add(success('First Name: ${passportInfo["firstName"]}'))
        ..add(success('Last Name: ${passportInfo["lastName"]}'))
        ..add(success('Age: ${passportInfo["age"]} years old'))
        ..add(success(
            'Number of People in Family: ${passportInfo["familySize"]}'));
    } on ValidationException catch (e) {
      $errors!.children.addAll(e.errors.map((error) {
        return LIElement()..text = error;
      }));
    }
  });
}

LIElement success(String str) => LIElement()
  ..classes.add('success')
  ..text = str;
