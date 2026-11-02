---
requires:
  - ../core/principles.md
---
# Ruby Style

These rules keep Ruby code consistent across the codebase. RuboCop enforces most of them; the rest are checked in review.

## Strings

Use single quotes for Ruby string literals that contain no interpolation.

Use double quotes only when the string interpolates a value or contains an escape sequence such as a newline. Heredocs use the squiggly form so indentation follows the surrounding code.

## Files

Every Ruby file starts with the magic comment # frozen_string_literal: true.

One class or module per file, and the file path mirrors the constant path: a class named Billing::InvoiceBuilder lives in billing/invoice_builder.rb. Keep files under three hundred lines; a longer file usually hides a second class.

## Naming

- Methods and variables use snake_case; classes and modules use CamelCase; constants use SCREAMING_SNAKE_CASE.
- Predicate methods end in a question mark and return true or false, never nil.
- Methods that mutate their receiver or raise where a sibling would not end in an exclamation mark.
- Avoid abbreviations except for well-known ones such as id, url and html.

## Methods

Keep methods short: under fifteen lines is the target, thirty is the limit. Prefer keyword arguments once a method takes more than two parameters, and give optional keywords sensible defaults. Return early with guard clauses instead of nesting conditionals.

## Hashes and collections

Use the modern hash syntax with symbol keys for data you build in code. Keep string keys for data parsed from JSON or YAML. Prefer each, map, select and reduce over manual index loops, and prefer the percent literal for word and symbol arrays.

## Comments

Write comments that explain why, not what. A comment that restates the code will drift out of date; a comment that records a constraint or a surprising decision earns its place. Public classes carry a one-line summary comment above the definition.

## Formatting

Two spaces for indentation, no tabs, and a maximum line length of one hundred and twenty characters. Leave one blank line between methods. Let the formatter settle layout questions so reviews can focus on behavior.
