---
paths:
  - spec/factories/**/*.rb
---
# Test Factories

Factories build valid objects for tests with as little setup as possible. A factory that needs ten overrides in every spec is not doing its job.

## Minimal defaults

Each factory defines only the attributes required for a valid record. Optional attributes stay nil unless a trait sets them. Use sequences for unique fields such as email addresses and slugs so parallel tests do not collide.

- Name the factory after the model, in singular snake_case.
- Put each factory in its own file named after the model.
- Keep default values obviously fake, such as an example dot test email domain.

## Traits

Use traits for meaningful variations: a published post, an expired subscription, an admin user. Name traits after the state they represent, not after the attributes they set. Combine traits in specs instead of defining new factories for every combination.

## Associations

Prefer build strategies that do not save associated records unless the test needs them in the database. Deep association chains slow the suite and hide what the test actually depends on. When a test needs a specific parent, pass it in explicitly.

## Callbacks

Use after build or after create callbacks sparingly, only to establish invariants every instance needs. Callbacks that create extra records surprise readers and make tests slower than they look.

## Linting

Run the factory linter in continuous integration so a factory that no longer produces a valid record fails fast, with a clear message, instead of breaking dozens of unrelated specs.

## Data that looks real

Factory data should look plausible but never be real. Do not copy names, addresses or email addresses from production, even for a single test. Use the fake data generator with a fixed seed so failures are reproducible.
