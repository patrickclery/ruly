# Code Review

Review is how the team shares knowledge and catches problems early. It is not a gate to pass or a contest to win.

## What to look for

Read the description first, then the tests, then the code. Ask whether the change does what it says, whether it is tested at the right level, and whether the next person will understand it.

- Correctness: edge cases, error handling, concurrency, data migrations.
- Design: does the change fit the existing structure, or fight it?
- Security: input validation, authorization checks, secrets, logging of personal data.
- Operability: logs, metrics and alerts for new behavior; a rollback plan for risky changes.
- Readability: names, comments that explain why, size of methods and classes.

## Writing comments

Be specific and kind. Explain the reason behind a request, and suggest an alternative when you can. Label comments by weight so the author knows what blocks the merge:

- blocking: must change before merge.
- suggestion: worth considering, the author decides.
- nit: trivial style point, fine to ignore.
- question: you want to understand, not necessarily change anything.

Praise what is good. A short "nice simplification" tells the author what to keep doing.

## Response time

Start a review within one working day of being asked. If you cannot, say so and suggest another reviewer. Large pull requests can be reviewed in passes; post what you have so the author can start on it.

## Approving

Approve when the remaining comments are suggestions and nits. Do not hold an approval hostage to unrelated improvements; ask for a follow-up issue instead. If you approve with blocking comments outstanding, you are trusting the author to address them before merging, so say so explicitly.

## Disagreements

When author and reviewer disagree after two rounds, move the discussion to a short call or bring in a third person. Record the outcome in the pull request.

## Reviewing tests

Read the tests as carefully as the code. Check that a test would fail if the behavior broke, that it covers the error paths and edge cases named in the description, and that it does not depend on timing or order. A test that only exercises the happy path gives false confidence.
