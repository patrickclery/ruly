---
requires:
  - ../git/commits.md
---
# Pull Requests

A pull request is a request for someone else's time. Make it easy to say yes.

## Before opening

- Rebase onto the latest main branch and make sure the build passes locally.
- Read your own diff top to bottom as if you were the reviewer. Remove debugging output, commented-out code and unrelated changes.
- Keep the diff under four hundred changed lines where you can. Split larger work into a stack of smaller pull requests.

## Title and description

The title follows the same format as a commit subject. The description answers three questions: what changed, why it changed and how it was tested. Link the issue. For user-facing changes, include a screenshot or a short recording of the before and after.

Point the reviewer to the riskiest part of the change and to anything you are unsure about. A sentence such as "the retry logic in the payment client is the part I would like a second opinion on" focuses the review where it matters.

## Draft pull requests

Open a draft early when you want feedback on direction rather than details. Say in the description what kind of feedback you want. Mark it ready for review only when it is complete.

## During review

Respond to every comment, either with a change or with a short explanation. Resolve a conversation only after the reviewer agrees or after you have made the requested change. Push follow-up commits rather than force-pushing, so the reviewer can see what changed.

## Merging

The author merges, after approval and a green build. If the main branch moved and the merge is not trivial, rebase and let the build run again. Check the deployment after merge and watch the error tracker for the first hour.

## Stacked pull requests

When a change depends on another open pull request, base it on that branch and say so at the top of the description. Merge the stack from the bottom up, and rebase the remaining branches after each merge.
