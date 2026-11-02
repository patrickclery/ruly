# Flaky Tests

A flaky test passes and fails on the same code. Flaky tests train the team to ignore red builds, which is worse than having no test at all.

## Policy

When a test fails in continuous integration and passes on retry, treat it as a bug, not as bad luck. Open an issue with the failing build link, the seed and the error text. If the fix is not obvious within a day, quarantine the test with a tag that skips it and links the issue, so the main branch stays trustworthy.

Quarantined tests are reviewed every week. A test that stays quarantined for a month is either fixed or deleted, with a note explaining what coverage was lost.

## Common causes

- Order dependence: a test relies on state left behind by another test. Run the suite with a random seed and use the reported seed to reproduce.
- Time: a test assumes the current date, a time zone or that two timestamps differ. Freeze time explicitly.
- Asynchronous work: a test checks for a result before a background job or a browser action finished. Wait for a specific condition with a timeout instead of sleeping.
- Shared external resources: a test talks to a real service, a shared cache or a fixed port. Stub it or give each process its own resource.
- Unordered collections: a test compares a list whose order the database does not guarantee. Sort before comparing or match without order.

## Reproducing

Run the failing file in a loop until it fails, with the same seed as the failing build. Increase parallelism to surface races. Once you can reproduce it, the fix is usually small; write it up in the issue so the pattern is easier to spot next time.

## Prevention

Review new tests for the causes above. A reviewer who sees a sleep call, a hard-coded date or a dependency on test order should ask for a change before merging.

## Retries in the pipeline

Automatic retries in the pipeline hide flakiness instead of fixing it. If the pipeline retries failed tests, it must also report every test that needed a retry, and those reports feed the weekly quarantine review.
