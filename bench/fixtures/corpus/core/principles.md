# Engineering Principles

These principles apply to every change, in every part of the codebase. When a more specific rule disagrees with one of them, the specific rule wins for its own area.

## Small, reviewable changes

Small, reviewable changes beat large ones. A change that touches one concern can be read in one sitting, reverted in one step and bisected without guesswork. When a task grows past a few hundred lines of diff, stop and split it: land the refactor first, then the behavior change on top of it.

- One pull request, one purpose. Formatting sweeps and dependency bumps travel alone.
- Keep the build green on every commit, not only on the last one.
- Delete dead code in the same change that makes it dead.

## Prefer the simplest design

Prefer the simplest design that solves the problem in front of you. Do not build for requirements nobody has stated. An extra layer of indirection costs every future reader a little time; it has to pay that back with a concrete benefit you can name today.

- Reach for a plain method before a class, and a class before a framework.
- Duplicate a few lines twice before extracting a shared helper; extract on the third copy.
- Configuration is code. A new setting needs a default, a test and a reason to exist.

## Make it observable

Every feature should be observable in production without attaching a debugger. That means structured log lines at the boundaries, metrics for anything with a latency or a failure rate, and error reports that carry enough context to reproduce the problem.

## Leave the campsite cleaner

When you touch a file, leave it a little better than you found it: a clearer name, a missing test, a stale comment removed. Keep these improvements small and inside the scope of the change so the reviewer can still see the main point.

## Ask early

If a requirement is ambiguous, ask before writing code. A two-line question in the issue thread is cheaper than a day of work in the wrong direction. Write down the answer where the next person will find it, usually in the issue itself.

## Automate the second time

The first time you do a manual task, take notes. The second time, follow the notes and fix what was missing. The third time, script it and check the script in next to the code it serves.
