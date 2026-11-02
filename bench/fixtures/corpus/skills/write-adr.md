---
name: write-adr
description: Write an architecture decision record for a design choice the team has made.
---
# Write an ADR

Use this skill when the team makes a decision that is expensive to reverse: a new dependency, a data model change, a new service boundary or a change in how components communicate.

## Location and naming

Each record is a markdown file under docs/adr/, numbered in sequence with a short hyphenated title, for example docs/adr/0042-use-event-queue-for-billing.md. Records are never deleted; a reversed decision gets a new record that supersedes the old one.

## Sections

- Status: proposed, accepted, superseded or rejected, with the date.
- Context: the problem and the forces at play, including constraints and what happens if nothing changes.
- Options: the alternatives considered, each with its main benefits and costs.
- Decision: the option chosen, stated in one or two sentences.
- Consequences: what becomes easier, what becomes harder and what follow-up work is needed.

## Process

Open the record as a pull request with status proposed. Discussion happens in the review. Once accepted, update the status and merge. Link the record from the issues and pull requests that implement it.
