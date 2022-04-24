# Angel3 Paginate

![Pub Version (including pre-releases)](https://img.shields.io/pub/v/angel3_paginate?include_prereleases)
[![Null Safety](https://img.shields.io/badge/null-safety-brightgreen)](https://dart.dev/null-safety)
[![Gitter](https://img.shields.io/gitter/room/angel_dart/discussion)](https://gitter.im/angel_dart/discussion)
[![License](https://img.shields.io/github/license/dukefirehawk/angel)](https://github.com/dukefirehawk/angel/tree/master/packages/paginate/LICENSE)

Platform-agnostic pagination library, with custom support for the [Angel3](https://angel3-framework.web.app/).

## Installation

In your `pubspec.yaml` file:

```yaml
dependencies:
  angel3_paginate: ^6.0.0
```

## Usage

This library exports a `Paginator<T>`, which can be used to efficiently produce instances of `PaginationResult<T>`. Pagination results, when serialized to JSON, look like this:

```json
{
  "total" : 75,
  "items_per_page" : 10,
  "previous_page" : 3,
  "current_page" : 4,
  "next_page" : 5,
  "start_index" : 30,
  "end_index" : 39,
  "data" : ["<items...>"]
}
```

Results can be parsed from Maps using the `PaginationResult<T>.fromMap` constructor, and serialized via their `toJson()` method.

To create a paginator:

```dart
import 'package:angel3_paginate/angel3_paginate.dart';

void main() {
  var p = new Paginator(iterable);
  
  // Get the current page (default: page 1)
  var page = p.current;
  print(page.total);
  print(page.startIndex);
  print(page.data); // The actual items on this page.
  p.next(); // Advance a page
  p.back(); // Back one page
  p.goToPage(10); // Go to page number (1-based, not a 0-based index)
}
```

The entire Paginator API is documented, so check out the DartDocs.

Paginators by default cache paginations, to improve performance as you shift through pages. This can be especially helpful in a client-side application where your UX involves a fast response time, i.e. a search page.
