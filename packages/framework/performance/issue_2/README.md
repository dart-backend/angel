# Issue 2 benchmark

Compares the Angel3, Shelf and Relic apps of [issue 2](../../../../doc/issues/issue-2.md), plus the same routes on plain `dart:io` as the ceiling a framework on `dart:io` can reach.

## Contents

- `bin/angel.dart`, `bin/shelf.dart`, `bin/relic.dart`: the apps of the issue, unchanged except that `ISOLATES` and `PORT` can be set from the environment.
- `bin/raw.dart`: the same three routes on plain `dart:io`.
- `bin/load.dart`: an HTTP/1.1 load generator over keep-alive connections, used because `wrk` is not available here. A `*` in the path is replaced by a value that differs on every request.
- `bin/profile.dart`: samples the CPU of a server started with `--observe` and prints self and inclusive time per function.
- `bin/route_bench.dart`: times `Router.resolveAbsolute` without its cache, single-threaded, which a busy machine disturbs less than the HTTP benchmarks.
- `run.sh`: builds everything AOT with `dart build cli` and benchmarks every server on every route.
- `ab.sh`: compares builds of servers given as paths, alternating them several times per route so that load on the machine affects them alike.
- `results/`: the output of the runs below.

The `pubspec.yaml` overrides the Angel3 packages with those of the workspace, so the benchmarks measure the code here, not the versions on pub.dev.

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

## After fix 2: routes matched with a RegExp (angel3_route 10.1.1)

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

## Suggested fixes, by measured payoff

1. ~~Keep the content type as a `MediaType` field and give the header string only when needed, or cache the parse keyed by the header string. This is worth about 12% on the cheapest routes.~~ Done in 10.2.1, see above.
2. ~~Stop route parsing on cache misses: precompile each route to a `RegExp` (as Shelf does), or key the cache by the matched route rather than the request path. This is worth about 15–18% on parameterized routes and should close most of the 37% gap.~~ Done in `angel3_route` 10.1.1, see above. What is left is the two route caches (the driver's and the flattened router's), which cost a lookup, an insertion and an eviction for every new path; about 6% of CPU on `GET /user/*`.
3. Validate only headers that were set or changed, with a code-unit check instead of a regex, and build the default headers without `CaseInsensitiveMap.from`. This is worth about 5–8%.
4. Trim the future chain in `handleRawRequest` and `sendResponse`: a synchronous path when a handler returns a value, and no `Future.forEach` when there are no shutdown hooks. This should be measured after fixes 1–3.
