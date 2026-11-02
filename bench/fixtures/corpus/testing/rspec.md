---
paths:
  - spec/**/*_spec.rb
requires:
  - ../ruby/style.md
---
# RSpec Conventions

Specs are executable documentation. A reader should understand what a class does from its spec without opening the class.

## Expectations

Write RSpec expectations with expect(...); never use the should syntax.

Use the matcher that states intent most directly: eq for values, be for identity and predicates, include for collections, raise_error with a class and a message pattern for failures. Avoid comparing whole serialized structures when only one field matters.

## Structure

- One top-level describe per file, naming the class under test.
- Nested describe blocks name a method: a hash sign for instance methods, a dot for class methods.
- Context blocks start with when, with or without and describe one condition.
- Example descriptions read as a sentence about behavior, never "works" or "is correct".

## Setup

Use let for data an example reads, and let! only when the record must exist before the example runs. Keep setup close to the examples that need it; a before block at the top of a long file is hard to connect to the example that depends on it. Prefer factories over fixtures, and build rather than create when the database is not needed.

## Isolation

Every example runs alone and in any order. Do not share state through class variables, globals or files on disk. Stub time with the time helpers rather than sleeping. Stub network calls at the HTTP layer so a spec never reaches a real service.

## Doubles

Use verified doubles so a stub fails when the real method is renamed. Stub collaborators at the boundary of the unit under test, not the unit itself. If a spec needs more than three stubs to run, the class probably has too many dependencies.

## Speed

The whole unit suite should run in under a minute on a laptop. Tag slow integration specs so they can be skipped locally and run in continuous integration. When a spec file is slow, look for records created that the examples never read.
