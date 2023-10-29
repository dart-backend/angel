import 'package:angel3_validate/angel3_validate.dart';
import 'package:test/test.dart';

void main() {
  final Validator orderItemSchema = Validator({
    'id': [isInt, isPositive],
    'item_no': isString,
    'item_name': isString,
    'quantity': isInt,
    'description?': isString
  });

  final Validator orderSchema = Validator({
    'id': [isInt, isPositive],
    'order_no': isString,
    'order_items*': [isList, everyElement(orderItemSchema)]
  }, defaultValues: {
    'order_items': []
  });

  group('json data', () {
    test('validate with child element', () {
      var orderItem = {
        'id': 1,
        'item_no': 'a1',
        'item_name': 'Apple',
        'quantity': 1
      };

      var formData = {
        'id': 1,
        'order_no': '2',
        'order_items': [orderItem]
      };
      var result = orderSchema.check(formData);

      expect(result.errors.isEmpty, true);
    });

    test('validate empty child', () {
      var formData = {'id': 1, 'order_no': '2'};
      var result = orderSchema.check(formData);

      expect(result.errors.isEmpty, true);
    });

    test('validate invalid child field', () {
      var orderItem = {
        'id': 1,
        'item_no': 'a1',
        'item_name': 'Apple',
        'quantity': 1,
        'description': 1
      };

      var formData = {
        'id': 1,
        'order_no': '2',
        'order_items': [orderItem]
      };
      var result = orderSchema.check(formData);

      expect(result.errors.isEmpty, false);
    });
  });
}
