# Issue 174

## **Proposal: Improve Post-Handler Middleware Logic via `next()` or Default Buffering**

**Is this a bug report or a feature request?**

Feature Request / Usability Improvement

**Description**

Currently, Angel3's middleware execution is designed as a sequential, performance-first chain. A middleware runs, and if it returns `true`, the next handler in the chain is invoked. This model is highly efficient for pre-processing logic.

However, it makes a very common and powerful pattern—running logic *after* the main handler has completed—unintuitive and difficult to implement. This pattern is essential for tasks like:

* **Metrics Collection:** For robust monitoring and observability. For example, incrementing an "in-flight requests" counter *before* the handler, and decrementing it *after*. This also includes logging the final status code of the response (e.g., 200, 404, 500) to aggregate statistics on success and error rates, which can only be reliably captured after the entire request has been processed.
* **Response Time Logging:** Tracking the total time taken to process a request from start to finish.
* **Database Transaction Management:** Wrapping a handler in a transaction that is committed on success or rolled back on failure.
* **Modifying a Response Body:** For example, wrapping a generated JSON object in a standardized envelope like `{ "data": ... }`.

To achieve this today, a developer has two main options:

1. **The "Wrapper" Function Pattern:** Manually creating a higher-order function that wraps the main handler. This is powerful but verbose and not an idiomatic, first-class feature of the framework.
2. **`responseFinalizers` with `useBuffer()`:** Using `responseFinalizers` requires manually calling `res.useBuffer()` in *every* handler that generates a response. This is easy to forget, adds boilerplate, and leads to unexpected behavior (finalizers not running) if omitted.

The current design prioritizes stream-based performance by default but at the cost of developer experience (DX) and flexibility for these common use cases. Developers coming from ecosystems like Express.js or Koa.js often find this behavior surprising.

**Proposed Solution**

I propose improving this workflow by making post-handler logic a more natural, first-class citizen. There are two potential paths to achieve this, and I'd like to open a discussion on which is more aligned with Angel3's vision.

---

### **Proposal 1: Introduce an Express-style `next()` Middleware Pattern**

This proposal makes the "Wrapper" pattern a core feature of the framework. A `next` callback would be passed to handlers, allowing developers to explicitly control the execution flow.

A middleware could look like this:

```dart
Future<void> timingMiddleware(RequestContext req, ResponseContext res, Future<void> Function() next) async {
  final stopwatch = Stopwatch()..start();
  try {
    // Await the rest of the chain
    await next();
  } finally {
    // This code runs *after* the main handler and response generation
    stopwatch.stop();
    if (res.isBuffered) {
        res.headers['X-Execution-Time-ms'] = stopwatch.elapsedMilliseconds.toString();
    }
  }
}
```

#### Implementation Suggestion

This would be a significant change. A non-breaking approach could be to introduce a new router method, like `app.add()`, that uses a different pipeline runner designed for this pattern, leaving `app.get()`, `app.post()`, etc., with their current high-performance behavior.

The core change would be in a pipeline runner, conceptually similar to this snippet, which composes `Future`s:

```dart
// In a new helper or modified driver logic
Future<void> runNextablePipeline(List<Function> handlers, RequestContext req, ResponseContext res) {
  int index = -1;

  Future<void> dispatch(int i) {
    if (i <= index) return Future.error(StateError('next() called multiple times'));
    index = i;

    if (i >= handlers.length) {
      return Future.value();
    }

    final handler = handlers[i];

    // The 'next' function recursively calls dispatch for the next handler
    final next = () => dispatch(i + 1);

    // Call the current handler with req, res, and the next() function
    return Future.sync(() => handler(req, res, next));
  }

  return dispatch(0);
}
```

---

### **Proposal 2: Enable Response Buffering by Default (Opt-in to Streaming)**

This proposal flips the current default. Instead of developers "opting-in" to flexibility with `res.useBuffer()`, they would "opt-in" to performance with a new method.

1. **Make Buffering the Default:** All responses are automatically buffered. This would make `responseFinalizers` work out-of-the-box for every request, dramatically simplifying their use.
2. **Introduce an "Opt-out" for Streaming:** Add a new method like `res.streamBody(Stream<List<int>> stream)` or `res.sendUnbuffered()` for specific routes where streaming performance is critical (e.g., large file downloads).

#### Implementation Suggestion

This change is simpler and less disruptive. It can be implemented by calling `useBuffer()` in the `ResponseContext` constructor and adding a global configuration flag.

**File: `packages/framework/lib/src/core/server.dart`**
Add a new property to the `Angel` class constructor to make this non-breaking.

```dart
class Angel extends Routable {
  // ... existing properties
  final bool bufferResponsesByDefault;

  Angel({
    // ... existing parameters
    this.bufferResponsesByDefault = false, // Default to current behavior
  }) : super(reflector) {
    // ...
  }
}
```

**File: `packages/framework/lib/src/http/http_response_context.dart`**
Modify the constructor to check this flag.

```dart
class HttpResponseContext extends ResponseContext<HttpResponse> {
  // ...

  HttpResponseContext(this.rawResponse, Angel? app, [this._correspondingRequest]) {
    this.app = app;
    // Check the global flag to enable buffering automatically
    if (app?.bufferResponsesByDefault == true) {
      useBuffer();
    }
  }

  // ...
}
```

This same logic would be applied to `Http2ResponseContext`.

**Benefits of these Proposals**

* **Improved Developer Experience:** Both proposals make a common pattern significantly more intuitive and less error-prone.
* **Reduced Boilerplate:** Proposal 2 completely removes the need to call `res.useBuffer()` repeatedly. Proposal 1 makes wrapping idiomatic.
* **Easier Onboarding:** The patterns would be more familiar to developers coming from other major web frameworks.
* **More Robust Middleware:** Enables easier development of powerful middleware for transactions, logging, metrics collection, and response shaping.

I believe either of these changes would be a valuable improvement to the framework's usability. Thank you for considering this proposal.
