# Commit Messages

The commit log is the long-term memory of the codebase. Write messages for the person who runs blame on a confusing line two years from now.

## Subject line

Commit subjects follow type(scope): summary, in lower case, at most 72 characters.

The type is one of feat, fix, refactor, perf, test, docs, chore or ci. The scope names the component touched, such as billing or auth. The summary is written in the imperative mood, as if completing the sentence "this commit will", and has no trailing period.

## Body

Leave one blank line after the subject, then explain why the change was needed and what it does at a high level. The diff already shows how. Wrap the body at seventy-two characters. Reference the issue key on its own line at the end.

- Explain the problem before the solution.
- Mention alternatives you rejected if a reviewer is likely to suggest them.
- Call out anything risky: a migration, a changed default, a removed endpoint.

## Atomic commits

Each commit should build and pass tests on its own, so bisecting works. Separate mechanical changes such as renames and formatting from behavior changes. If you need the word "and" in the summary, consider two commits.

## Rewriting history

Rewrite your own branch freely before review to tell a clean story: squash fixups, reorder, split. Never rewrite history that others have pulled, and never force-push the main branch. After review starts, add new commits rather than amending, so reviewers can see what changed since their last pass.

## Co-authors

When you pair or take over someone else's work, credit them with a co-author trailer at the end of the message.

## Generated files

Commit generated files only when the build cannot produce them, and then in a separate commit whose subject says they are generated. Lock files are committed together with the manifest change that produced them, so the two never drift apart.
