//import 'dart:html';
import 'dart:js_interop';

import 'package:web/web.dart';
import 'package:angel3_validate/angel3_validate.dart';

final $errors = document.querySelector('#errors') as HTMLUListElement?;
final $form = document.querySelector('#form') as HTMLFormElement?;
final $blank = document.querySelector('[name="blank"]') as HTMLInputElement?;

final Validator formSchema = Validator(
  {
    'firstName*': [isString, isNotEmpty],
    'lastName*': [isString, isNotEmpty],
    'age*': [isInt, greaterThanOrEqualTo(18)],
    'familySize': [isInt, greaterThanOrEqualTo(1)],
    'blank!': [],
  },
  defaultValues: {'familySize': 1},
  customErrorMessages: {
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
        "I told you to leave that field blank, but instead you typed '{{value}}'...",
  },
);

void main() {
  $form!.onSubmit.listen((e) {
    e.preventDefault();
    //$errors!.removeChild(child)
    $errors!.remove();

    var formData = {};

    for (var key in ['firstName', 'lastName', 'age', 'familySize']) {
      formData[key] =
          (document.querySelector('[name="$key"]') as HTMLInputElement).value;
    }

    if ($blank!.value.isNotEmpty) formData['blank'] = $blank!.value;

    print('Form data: $formData');

    try {
      var passportInfo = formSchema.enforceParsed(formData, [
        'age',
        'familySize',
      ]);

      $errors!.children
        ..add(success('Successfully registered for a passport.'))
        ..add(success('First Name: ${passportInfo["firstName"]}'))
        ..add(success('Last Name: ${passportInfo["lastName"]}'))
        ..add(success('Age: ${passportInfo["age"]} years old'))
        ..add(
          success('Number of People in Family: ${passportInfo["familySize"]}'),
        );
    } on ValidationException catch (e) {
      $errors!.children.add(
        e.errors.map((error) {
          return HTMLLIElement()..textContent = error;
        }).jsify(),
      );
    }
  });
}

HTMLLIElement success(String str) => HTMLLIElement()
  ..classList.add('success')
  ..textContent = str;
