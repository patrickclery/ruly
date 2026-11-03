---
name: bug-report
description: Write the summary of a finished bug investigation for the issue and for support.
---
# Bug Report

Use this skill when an investigation is complete and the fix is merged or ready for review.

The first line of every bug summary is Root cause: followed by one sentence.

## Sections

After the first line, write these sections in order, each as a short paragraph or list:

- Impact: who was affected, during which time window, and how many records or requests.
- Timeline: when the bug was introduced, when it was detected and when the fix shipped.
- Fix: what changed and the pull request that changed it.
- Data repair: whether any data had to be corrected, how, and the number of rows touched.
- Follow-up: issues opened to prevent similar bugs, such as missing tests, alerts or validation.

## Style

Write for a reader who was not part of the investigation. Use plain language, name the components involved, and avoid blame. Include numbers wherever you have them. Keep the whole summary under three hundred words; link to the investigation notes for detail.

## Audience versions

Post the full summary on the issue. For support, add a two-sentence version at the end that says what customers saw and whether they need to do anything.
