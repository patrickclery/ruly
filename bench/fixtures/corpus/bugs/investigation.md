---
requires:
  - logs.md
---
# Bug Investigation

A good investigation ends with a root cause that explains every symptom, a fix, and a test that would have caught the bug.

## Reproduce first

Before changing code, reproduce the bug. Collect the exact steps, the account or record involved, the time it happened and the error text. Reproduce it locally or in a staging environment with similar data. If you cannot reproduce it, say so in the issue and list what you tried.

## Narrow it down

- Find the first moment the system did something wrong. Work backward from the visible symptom through logs, queries and recent changes.
- Check what changed: deploys, configuration changes, data migrations and dependency updates around the time the bug first appeared.
- Bisect when a bug appeared between two known versions. It is faster than reading every commit.
- Write down each hypothesis and the evidence that confirmed or ruled it out. This becomes the investigation summary.

## Root cause versus symptom

A fix that only handles the symptom, such as rescuing an error or adding a nil check, often hides the real problem. Ask why the bad state was possible in the first place. Keep asking until the answer is a decision or a defect in code you control.

## The fix

Write a failing test that reproduces the bug before fixing it. The test proves the fix works and protects against regressions. Keep the fix minimal; refactoring that the fix revealed as necessary goes in a separate change.

## Data repair

If the bug corrupted data, plan the repair separately from the code fix. Write the repair as a script that can run twice safely, try it on a copy of production data and record the number of rows changed.

## Closing the loop

Update the issue with the root cause, the fix and the affected scope: which users, which time window, which records. Tell support and the reporter in plain language what happened and whether they need to do anything.

## Time boxing

Set a time box for each stage of an investigation. If reproduction takes more than half a day, stop and share what you have learned; someone with more context may see the answer immediately. Note in the issue how much time was spent so future estimates improve.
