# Issue 2 benchmark

Compares the Angel3, Shelf and Relic apps of [issue 2](../../../../doc/issues/issue-2.md), plus the same routes on plain `dart:io` as the ceiling a framework on `dart:io` can reach.

## Contents

- `bin/angel.dart`, `bin/shelf.dart`, `bin/relic.dart`: the apps of the issue, unchanged except that `ISOLATES` and `PORT` can be set from the environment.
- `bin/angel_runner.dart`: the Angel3 app of the issue served by `Runner` of `angel3_production`, with its defaults, instead of isolates spawned by hand.
- `bin/raw.dart`: the same three routes on plain `dart:io`.
- `bin/load.dart`: an HTTP/1.1 load generator over keep-alive connections, used because `wrk` is not available here. A `*` in the path is replaced by a value that differs on every request.
- `bin/profile.dart`: samples the CPU of a server started with `--observe` and prints self and inclusive time per function, and the time in `dart:async` by the first caller outside it.
- `bin/microtasks.dart`: counts the microtasks each request schedules, and times requests, through `AngelHttp` with mock requests, so without sockets.
- `bin/route_bench.dart`: times `Router.resolveAbsolute` without its cache, single-threaded, which a busy machine disturbs less than the HTTP benchmarks.
- `run.sh`: builds everything AOT with `dart build cli` and benchmarks every server on every route.
- `ab.sh`: compares builds of servers given as paths, alternating them several times per route so that load on the machine affects them alike.
- `results/`: the output of the runs below.

The `pubspec.yaml` overrides the Angel3 packages with those of the workspace (`angel3_framework` and `angel3_production` among them), so the benchmarks measure the code here, not the versions on pub.dev.

## Running

```sh
dart pub get
./run.sh                      # all servers
./run.sh angel shelf          # some of them
TRIALS=3 DURATION=20 ./run.sh # longer runs
```

The servers run on `SERVER_CPUS` (default `0,1`) with `ISOLATES` isolates (default 2), and the load generator on `LOAD_CPUS` (default `2,3`), so the two do not compete for a core.

To profile Angel3 (the VM service needs the JIT):

```sh
ISOLATES=2 taskset -c 0,1 dart run --observe=8181/127.0.0.1 --disable-service-auth-codes --no-dds bin/angel.dart &
build/load/bundle/bin/load -d 8 'GET /user/*'   # warm up the JIT
dart run bin/profile.dart ws://127.0.0.1:8181/ws 8 200 > results/profile.txt &
build/load/bundle/bin/load -d 9 'GET /user/*'
```

## Results

Run on 2026-11-25, Dart 3.14.1, Linux x64 with 4 CPUs. Servers had 2 isolates on 2 cores, and the load generator 2 isolates on the other 2 cores, with 64 connections. Each figure is the mean of two 10 s runs after a 3 s warmup, in requests per second (see [results/run-1.txt](results/run-1.txt)). No run had errors or non-2xx responses.

| Route | dart:io | Angel3 | Shelf | Relic | Angel3 / Shelf | Angel3 / dart:io |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `GET /` | 23,605 | 14,724 | 18,384 | 41,454 | 80% | 62% |
| `GET /user/42` (same path) | 18,555 | 11,595 | 13,071 | 39,531 | 89% | 62% |
| `GET /user/*` (new path each request) | 18,376 | 8,502 | 13,439 | 38,794 | 63% | 46% |
| `POST /user` | 25,195 | 15,224 | 17,372 | 41,546 | 88% | 60% |

Relic reaches about 40k req/s with the same generator, so the generator does not cap the `dart:io` figures.

## Findings

1. **Relic is not comparable.** It serves through `relic_native`, not `dart:io`, and is about twice as fast as plain `dart:io` itself. No framework on `dart:io` can match it.
2. **Against Shelf, Angel3 is 11–20% slower on fixed paths, and 37% slower when the path varies.** Fixed paths hit Angel3's route caches, which are keyed by the whole path, so `/user/1`, `/user/2`, … miss both caches every time. Each miss runs the parser-combinator route matcher: `Router.resolve` takes 14% of CPU and `belatuk_combinator` 12%. Shelf matches with precompiled regexes and needs no cache.
3. **`ResponseContext.contentType` parses the header on every response.** The getter calls `MediaType.parse(headers['content-type'])`, which is built on regexes, and `HttpResponseContext._openStream` calls it for every response. That costs 11.9% of all CPU on `GET /` and 6.7% on `GET /user/*`. Regex matching is the largest Dart-side cost in the profile (17% self time on `GET /`).
4. **Building and validating headers costs about 8%.** On `GET /`, `validateHeaders` runs a regex on each header name (3.9%), and each response builds a validating case-insensitive header map from a literal (4.1%).
5. **Writing the response is mostly `dart:io`.** `sendResponse` is 47% inclusive on `GET /`, but most of that is `dart:io` closing the response and writing to the socket, which plain `dart:io` pays too.
6. **The request container is cheap.** Creating a child container and registering the request's objects takes about 1.3%, not the large cost a reading of the code suggested.
7. **The async chain is spread thinly.** Future bookkeeping (`future_impl.dart`) is about 7–8% self time. That is not a single hotspot, but it is several times what `dart:io` alone does.

## After fix 1: content type cache (10.2.1)

`ResponseContext.contentType` now reuses parsed headers, keyed by the header string. In the `GET /` profile ([results/profile-angel-get-root-after.txt](results/profile-angel-get-root-after.txt)), the getter fell from 11.9% to 0.5% of CPU, regex self time from 16.8% to 8.5%, and `_openStream` from 20.2% to 10.8%.

The machine was busy during the throughput runs (load average about 7), so the absolute figures are below those above. To compare fairly, the old and new builds were alternated three times per route, 8 s each after a 3 s warmup ([results/run-3-content-type-ab.txt](results/run-3-content-type-ab.txt)):

| Route | Before | After | Change |
| --- | ---: | ---: | ---: |
| `GET /` | 11,916 | 12,988 | +9.0% |
| `GET /user/42` | 10,446 | 12,091 | +15.7% |
| `GET /user/*` | 6,264 | 6,890 | +10.0% |
| `POST /user` | 11,954 | 12,157 | +1.7% |

The `POST /user` gain is within the noise of these runs. A same-time run of Angel3 and Shelf ([results/run-2-content-type.txt](results/run-2-content-type.txt)) had Angel3 at 100% of Shelf on `GET /`, up from 80%, but the noise makes that ratio rough.

## After fix 2: routes matched with a RegExp (angel3_route 10.2.0)

Each route is now compiled once to a single `RegExp`. Each segment of it is an atomic group (`(?=(?<g>…))\k<g>`), so that it matches exactly as the parser did, which never backtracks into an earlier segment. The few routes that cannot be written this way still use the parser. `test/regexp_match_test.dart` of `angel3_route` checks both on 35 route patterns and 55 paths.

Resolving without the cache ([results/route-bench.txt](results/route-bench.txt), best of five runs):

| Resolution | Before | After | Speed-up |
| --- | ---: | ---: | ---: |
| `GET /` | 2,039 ns | 1,033 ns | 2.0× |
| `GET /user/:id` | 11,339 ns | 2,490 ns | 4.6× |
| `POST /user` | 2,180 ns | 1,359 ns | 1.6× |
| `GET /orders/:id/history` (among 23 routes) | 28,822 ns | 4,346 ns | 6.6× |
| `GET /nope` (404) | 1,914 ns | 1,066 ns | 1.8× |

In the `GET /user/*` profile ([results/profile-angel-get-user-varying-after.txt](results/profile-angel-get-user-varying-after.txt)), resolution fell from 18.2% to 9.6% of CPU, and `belatuk_combinator` no longer appears; matching itself is 3.2%. The rest is the route caches, which miss on every new path, and building the handler pipeline.

Over HTTP, with the old and new builds and Shelf alternated three times per route ([results/run-4-route-regexp-ab.txt](results/run-4-route-regexp-ab.txt), load average about 10):

| Route | Before | After | Shelf |
| --- | ---: | ---: | ---: |
| `GET /user/*` | 6,888 | 8,643 | 9,346 |

The new build was faster in every round (+18% to +39%), and Angel3 went from 66% to 92% of Shelf on this route. Fixed paths are answered from the route caches, so this fix does not change them; their figures varied by ±25% between rounds of the same build.

## After fix 3: header validation (10.2.1)

Headers set with `[]=` were checked when set, then all checked again, with a `RegExp` per name, before they were sent. Now the second check runs only if a map method that bypasses `[]=` was used, names are checked with a lookup table, and the two default headers of each response are not checked at all.

In the `GET /` profile ([results/profile-angel-get-root-headers.txt](results/profile-angel-get-root-headers.txt)), `validateHeaders`, `isValidHeaderName` and `RegExp.hasMatch` no longer appear (4.9%, 5.7% and 5.7% inclusive before), and building a response fell from 4.3% to 1.4%. Regex self time on `GET /` is now 3.1% of CPU, from 16.1% before the three fixes.

Over HTTP ([results/run-5-headers-ab.txt](results/run-5-headers-ab.txt), alternated three times per route, load average 3 rising to 8), against the build with fix 1 only:

| Route | Fix 1 | Fixes 1–3 | Shelf |
| --- | ---: | ---: | ---: |
| `GET /` | 13,827 | 15,023 | 13,246 |
| `GET /user/42` | 10,982 | 10,353 | 9,059 |
| `GET /user/*` | 6,715 | 9,151 | 9,801 |
| `POST /user` | 12,456 | 13,577 | 12,464 |

`GET /` and `POST /user` gained about 9%. The `GET /user/42` difference is within the noise of this run (the old build ranged from 9,878 to 12,656 between rounds). `GET /user/*` includes fix 2.

## After fix 4: route caches (angel3_route 10.2.0, framework 10.2.1)

Both route caches evicted with `cache.remove(cache.keys.first)` on a `LinkedHashMap`, and moved a hit to the end by removing it and adding it again. Removed entries stay in a `LinkedHashMap` as tombstones until it is compacted, and `keys.first` steps over those at its start, so once a cache was full of distinct paths, each eviction stepped over hundreds. Timed alone, 1,024 entries and a new key each time took 1,906 ns a lookup, against 170 ns for a hash map with a linked list; repeated keys took 237 ns against 103 ns.

Both caches are now an `LruMap` of `angel3_route`, which does every operation in constant time. The driver also resolves a miss without the router's cache: in production that cache is behind the driver's, with the same keys, so it could only miss as well.

In the `GET /user/*` profile ([results/profile-angel-get-user-varying-cache.txt](results/profile-angel-get-user-varying-cache.txt)), `Router.resolveAll` (the router cache, 1.8%) and `Iterable.first` (1.3%) no longer appear, and `LruMap` costs 0.7%. Over HTTP ([results/run-6-route-cache-ab.txt](results/run-6-route-cache-ab.txt), against the build with fixes 1–3, alternated three times per route):

| Route | Fixes 1–3 | Fixes 1–4 | Shelf |
| --- | ---: | ---: | ---: |
| `GET /user/*` | 8,788 | 9,230 | 9,506 |

The new build was faster in every round, and Angel3 reached 97% of Shelf on this route. In that run `GET /` looked 6% slower, but `ab.sh` always ran the old build first; with the new build first and five rounds ([results/run-6b-route-cache-get-root.txt](results/run-6b-route-cache-get-root.txt)), the two were level (17,522 and 17,581).

## Profile after fixes 1–4

Profiled on 2026-11-26 on a quiet machine (load average 0.8), as above ([results/profile-angel-get-root-fixes-1-4.txt](results/profile-angel-get-root-fixes-1-4.txt), [results/profile-angel-get-user-varying-fixes-1-4.txt](results/profile-angel-get-user-varying-fixes-1-4.txt)). Self time by library, against the first profiles:

| Library | `GET /` before | `GET /` after | `GET /user/*` before | `GET /user/*` after |
| --- | ---: | ---: | ---: | ---: |
| Socket I/O (`socket_patch.dart`) | 27.8% | 34.4% | 25.0% | 33.8% |
| Futures (`future_impl.dart`) | 7.9% | 10.4% | 7.0% | 9.1% |
| `RegExp` | 16.1% | 3.1% | 11.1% | 6.6% |
| `belatuk_combinator` | | | 2.8% | |

Socket I/O, which plain `dart:io` pays as well, is now the largest share. Futures have grown because the rest has shrunk. What is left that Angel3 can change:

- **The request path is stripped with a `RegExp`.** `AngelHttp.createRequestContext` removes the leading and trailing slashes of every path with `replaceAll(RegExp(r'(^/+)|(/+$)'), '')`, which costs 3.5% of CPU on `GET /` and 5.0% on `GET /user/*`. It is the largest remaining regex use. On `GET /user/*` the rest is route matching (`_RouteRegExp.parse`, 3.6% inclusive).
- **The future chain** is about 9–10% self time, spread over `then`, `_propagateToListeners` and zone callbacks, with no single hotspot.
- **Writing the body.** On `GET /user/*`, `HttpResponseContext.add` costs 27.6% inclusive, most of it `dart:io` writing to the socket.

## After fix 5: request path stripping (angel3_route 10.2.0, framework 10.2.1)

`AngelHttp` and `AngelHttp2` now strip the slashes of each request path with `stripStraySlashes` of `angel3_route`, which scans code units, instead of `replaceAll(RegExp(r'(^/+)|(/+$)'), '')`. That function threw on an empty string, which is fixed as well. Timed alone, it takes 17 ns on `/` and 40 ns on `/user/123456`, against 595 ns and 1,605 ns with the `RegExp`.

In the `GET /user/*` profile ([results/profile-angel-get-user-varying-path-strip.txt](results/profile-angel-get-user-varying-path-strip.txt)), `String.replaceAll` no longer appears, `AngelHttp.createRequestContext` fell from 7.0% to 2.1% inclusive, and regex self time from 6.6% to 2.8%, all of it route matching. Over HTTP ([results/run-7-path-strip-ab.txt](results/run-7-path-strip-ab.txt), alternated three times per route, load average 2.4 rising to 7.8):

| Route | Fixes 1–4 | Fixes 1–5 | Shelf |
| --- | ---: | ---: | ---: |
| `GET /` | 14,004 | 14,289 | 13,533 |
| `GET /user/42` | 10,803 | 11,085 | 9,812 |
| `GET /user/*` | 9,263 | 9,784 | 9,906 |
| `POST /user` | 13,241 | 13,297 | 12,431 |

The new build was faster in 10 of 12 rounds and in every round of `GET /user/*`, where it reached 99% of Shelf. The gains of 0.4–5.6% are near the noise of a run on a machine this busy, but they agree with the 3.5–5% the profile gave the `RegExp`.

## Fix 6: the future chain (framework 10.2.1)

`bin/profile.dart` now also charges the time in `dart:async` to the first caller outside it. On `GET /` after fix 5 ([results/profile-angel-get-root-async-callers.txt](results/profile-angel-get-root-async-callers.txt)), it showed that of the 20% of `GET /` in `dart:async`, the framework's own calls start about 2.4%. 8% is running microtasks and events, shared by the framework and `dart:io`, and the rest is `dart:io`: the HTTP parser, the socket streams and the sink. A request through the mock schedules 7 microtasks, 8 in a zone, of which 4 are the framework's.

Two changes were tried:

1. **Running the pipeline without futures** while handlers give their results at once, and sending the response at once after them. This saved a microtask and about 1 µs a request, but it cannot be kept. The pipeline took one microtask after each handler, and code relies on it: a handler that calls `res.json(value)` without waiting for it and returns `false`, as `angel3_openapi` does, has its body written in that microtask (`serialize` awaits the serializer), and without it the response was sent empty. The pipeline runs as before, and `test/async_chain_test.dart` checks that such a handler, and such middleware, still work.
2. **Closing without needless futures.** `RequestContext.close` no longer runs `Future.forEach` when it has no shutdown hooks, `HttpResponseContext.close` is no longer `async`, and both give a `Future` that is complete already. A request schedules a microtask fewer.

With the second only, through the mock ([`bin/microtasks.dart`](bin/microtasks.dart), the builds alternated three times):

| Request | Microtasks before | after | ns before | ns after |
| --- | ---: | ---: | ---: | ---: |
| `GET /` | 7 | 6 | 16,391 | 14,329 |
| `GET /user/*` | 7 | 6 | 23,204 | 21,949 |
| `POST /user` | 7 | 6 | 14,859 | 13,826 |
| `GET /` in a zone | 8 | 7 | 15,486 | 14,555 |

A real request costs about 140 µs of CPU, so the 1–2 µs saved is about 1%, below the noise over HTTP ([results/run-8-async-chain-ab.txt](results/run-8-async-chain-ab.txt): the new build was faster in 6 rounds of 12). The future chain that is left belongs to `dart:io`, or to the framework's API: `createRequestContext` and `createResponseContext` return futures, which the driver must wait for.

The first change also showed that `angel3_shelf` hijacked a request in time only because the framework took a microtask or two before it sent the response: `shelf.Request.hijack` runs the hijack in a microtask. `embedShelf` now waits for the hijack, whatever the framework's timing.

## Served by `Runner` (angel3_production 10.2.0)

`bin/angel_runner.dart` serves the app of `bin/angel.dart` with `Runner`, as a deployed app would be: in production mode, which `Runner` sets by default since 10.2.0, with no zone per request, respawning on, and its instances logging to the main isolate. It listens on all addresses, as `bin/angel.dart` does, with `ISOLATES` instances on `PORT`.

The two were alternated three times per route, 8 s each after a 3 s warmup, with 2 isolates and 64 connections ([results/run-11-runner-ab.txt](results/run-11-runner-ab.txt), framework 10.3.0, load average 5.2 at the end):

```sh
./ab.sh build/angel/bundle/bin/angel build/angel_runner/bundle/bin/angel_runner
```

| Route | Isolates by hand | `Runner` | Change |
| --- | ---: | ---: | ---: |
| `GET /` | 20,204 | 19,573 | −3.1% |
| `GET /user/42` | 15,781 | 15,512 | −1.7% |
| `GET /user/*` | 13,254 | 13,125 | −1.0% |
| `POST /user` | 19,841 | 19,342 | −2.5% |

`Runner` costs about 2%. That is within the noise of one round (the rounds of `bin/angel.dart` on `GET /user/*` ranged from 12,527 to 13,642), but it was slower in 9 rounds of 12. Each instance has a `belatuk_pub_sub` client in its container and a logger that sends records to the main isolate, which serves no requests, but none of that runs per request in production mode. Before 10.2.0, `Runner` ran in development mode unless `ANGEL_ENV=production` was set, which resolves the routes of every request again; that, not `Runner` itself, was the cost to avoid.

### How requests are spread over the isolates

Copies of both servers that count the requests and the distinct client connections of each isolate ([results/run-12-runner-distribution.txt](results/run-12-runner-distribution.txt), 8 s of `GET /user/*`) show that `dart:io` spreads connections, not requests, over the isolates of a shared server: each connection is given to one isolate, which serves every request of it, as the load generator keeps them alive. The connections are not dealt round-robin, but in clumps that change from run to run:

| Server | Isolates | Connections | Requests per isolate | Connections per isolate |
| --- | ---: | ---: | --- | --- |
| By hand | 2 | 64 | 50.7% / 49.3% | 36 / 29 |
| `Runner` | 2 | 64 | 48.6% / 51.4% | 33 / 32 |
| By hand | 4 | 64 | 25.0 / 24.0 / 22.9 / 28.1% | 16 / 13 / 12 / 24 |
| `Runner` | 4 | 64 | 23.7 / 25.2 / 25.0 / 26.0% | 13 / 16 / 17 / 19 |
| By hand | 4 | 8 | 0 / 49.9 / 50.1 / 0% | 1 / 4 / 4 / 0 |
| `Runner` | 4 | 8 | 38.9 / 0 / 17.4 / 43.7% | 4 / 0 / 1 / 4 |

The connection counts include the one of the readiness check. Three more runs of 4 isolates and 8 connections by hand gave the busiest isolate 49%, 34% and 40% of the requests.

With 64 connections, as in every benchmark here, each isolate gets a fair share, so the figures above are not skewed by it. With few connections, some isolates, and the cores they would use, may get none. Both servers behave alike, as `HttpServer.bind(shared: true)` of `dart:io` gives out the connections, below Angel3. For a deployment, this means:

- A reverse proxy should keep several connections per isolate open to the app, as 64 connections did here.
- Connections that end now and then (`keepalive_requests` of nginx, or `HttpServer.idleTimeout`) are given out again, which evens the shares out over time.
- Processes of one isolate each, on ports of their own behind a load balancer, have the balancer spread the requests instead. `dart:io` cannot bind several processes to one TCP port: `reusePort` is only of `RawDatagramSocket`, for UDP.

## Suggested fixes, by measured payoff

1. ~~Keep the content type as a `MediaType` field and give the header string only when needed, or cache the parse keyed by the header string. This is worth about 12% on the cheapest routes.~~ Done in 10.2.1, see above.
2. ~~Stop route parsing on cache misses: precompile each route to a `RegExp` (as Shelf does), or key the cache by the matched route rather than the request path. This is worth about 15–18% on parameterized routes and should close most of the 37% gap.~~ Done in `angel3_route` 10.2.0, see above. The route caches that were left were fixed next, see "After fix 4".
3. ~~Validate only headers that were set or changed, with a code-unit check instead of a regex, and build the default headers without `CaseInsensitiveMap.from`. This is worth about 5–8%.~~ Done in 10.2.1, see above.
4. ~~Trim the future chain in `handleRawRequest` and `sendResponse`: a synchronous path when a handler returns a value, and no `Future.forEach` when there are no shutdown hooks.~~ Tried in 10.2.1, see "Fix 6": the synchronous path breaks handlers that do not wait for what they write, and the rest is worth about 1%.
5. ~~Strip the slashes of the request path in `AngelHttp.createRequestContext` with a code-unit scan instead of a `RegExp`. This is worth about 3.5–5%.~~ Done in 10.2.1, see "After fix 5".
