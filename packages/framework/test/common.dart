library;

import 'package:angel3_framework/angel3_framework.dart';
import 'package:matcher/matcher.dart';

class Todo extends Model {
  String? text;
  String? over;

  Todo({this.text, this.over});

  Map<String, dynamic> toJson() {
    return {'text': text, 'over': over};
  }
}

class BookService extends Service {
  @override
  Future<List> index([params]) async {
    print('Book params: $params');

    return [
      {'foo': 'bar'},
    ];
  }
}

void incrementTodoTimes(dynamic e) {
  IncrementService.times++;
}

@Hooks(before: [incrementTodoTimes])
class IncrementService extends Service {
  static int times = 0;

  @override
  @Hooks(after: [incrementTodoTimes])
  Future<List> index([params]) async => [];
}

class IsInstanceOf<T> implements Matcher {
  const IsInstanceOf();

  @override
  Description describeMismatch(
    item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    return mismatchDescription.add('$item is not an instance of $T');
  }

  @override
  Description describe(Description description) {
    return description.add('is an instance of $T');
  }

  @override
  bool matches(item, Map matchState) => item is T;
}
