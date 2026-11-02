# Branches

Branches are short-lived. A branch that lives longer than a few days drifts away from the main branch and becomes expensive to merge.

## Naming

Branch names are lower case, use hyphens between words and start with the issue key, followed by a short description: an issue key, a hyphen, then two to five words. Avoid personal prefixes; the branch belongs to the change, not to the author.

## Lifecycle

- Branch from an up-to-date main branch.
- Push early, even before the work is finished, so the work is backed up and visible.
- Rebase onto the main branch at least once a day while the branch is open.
- Delete the branch after it is merged.

## Merging

Merge through a pull request, never by pushing directly to the main branch. The main branch is protected: it requires a passing build and at least one approving review. Use squash merging for branches whose intermediate commits do not tell a useful story, and a regular merge when they do.

## Release branches

Release branches are cut from the main branch when a release is frozen. Only fixes go onto a release branch, and every fix lands on the main branch first and is then cherry-picked. Tag each release with its version number.

## Conflicts

Resolve conflicts on your branch, not in the merge commit on the main branch. When a conflict touches code you do not own, ask its author to look at your resolution before merging.

## Long-running work

When a feature takes weeks, keep merging small pieces to the main branch behind a feature flag instead of keeping a long-lived branch. The flag is removed in a follow-up once the feature is fully released.

## Cleaning up

Once a month, list remote branches that have not been updated in thirty days. Ask their authors whether they are still needed, and delete the ones that are not. A short branch list makes it easy to see what is actually in flight.
