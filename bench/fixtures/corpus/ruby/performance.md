# Ruby Performance

Measure before optimizing. Most slow code is slow because of input and output, not because of Ruby itself, so look at queries and network calls first.

## Measure

Use a profiler or a simple benchmark before and after a change, and put both numbers in the pull request description. An optimization without a measurement is a guess, and guesses add complexity that someone has to maintain.

- For a single method, a benchmark that runs it many thousands of times gives a stable number.
- For a request, use the timing breakdown from the application monitoring tool.
- For memory, compare object allocation counts rather than process size.

## Database access

The most common performance problem is the N plus one query: loading a list and then querying once per item. Preload associations you know you will touch, and add a test that counts queries for endpoints that render lists.

Select only the columns you need for large tables, and paginate anything that can grow without bound.

## Allocation

Avoid building large intermediate arrays when a lazy enumerator or a single pass will do. Frozen string literals already avoid one allocation per literal; keep them on. Prefer each_with_object or sum over map followed by a reduction when the intermediate array is large.

## Caching

Cache the result of expensive pure computations and slow remote reads, and always decide up front how the cache is invalidated. A cache with no invalidation story is a bug report waiting to be filed. Include a version segment in cache keys so a deploy can retire old entries.

## Background work

Move work that the user does not need to wait for into a background job: sending email, generating exports, calling slow third-party services. Keep the request path for work that decides the response.

## Concurrency

Reach for threads only around input and output, never for CPU-bound Ruby code. Share no mutable state between threads without a lock, and prefer a thread-safe queue over hand-rolled synchronization.

## Regressions

Add a performance budget for the endpoints that matter most, and fail the build when a change pushes them past it. A budget turns a slow decline over many releases into a single visible failure on the change that caused it.
