---
name: release-notes
description: Draft release notes for a tagged version from its merged pull requests.
---
# Release Notes

Use this skill when a release is tagged and the notes need to be written.

## Gathering changes

List the pull requests merged since the previous tag. Group them by type using their commit subjects: features, fixes, performance, and everything else. Drop pure refactors, test changes and chores unless they affect users or operators.

## Writing entries

Each entry is one line that describes the change from the user's point of view, followed by the pull request number. Write "Invoices can now be exported as spreadsheets" rather than "add export service".

- Breaking changes go first, under their own heading, with migration steps.
- Security fixes are listed without exploit details.
- Credit external contributors by handle.

## Review

Ask the release owner to review the notes before publishing. Check that every breaking change has upgrade instructions and that version numbers and dates are correct.
