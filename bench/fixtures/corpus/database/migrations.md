---
paths:
  - db/migrate/**/*.rb
---
# Database Migrations

Migrations change production data structures while the application is running. Write them so that a deploy never needs downtime and a rollback is always possible.

## Reversibility

Every migration defines up and down methods; never define change.

Explicit up and down methods make the rollback path visible in review. A migration whose down method cannot restore the previous state raises an irreversible migration error with a message explaining why, and the pull request says so.

## Safe changes

- Add columns as nullable, or with a default the database can apply without rewriting the table.
- Add indexes concurrently on large tables so writes are not blocked.
- Never rename or drop a column in one step. Add the new column, backfill, switch the code, then remove the old column in a later release.
- Keep schema changes and data backfills in separate migrations.

## Backfills

Backfill large tables in batches from a background job or a script, not inside the migration. Each batch is small enough to finish in a few seconds, and the job can resume after a failure. Log progress so the operator can see how far it got.

## Locks

Set a lock timeout on migrations that alter busy tables, so a migration waiting for a lock fails fast instead of queueing every other query behind it.

## Review

Every migration is reviewed by someone who knows the table's size and traffic. The pull request states the expected runtime on production data and whether the change is safe to run while the previous version of the application is still serving requests.

## Testing

Run the migration up, down and up again locally before opening the pull request. A migration that cannot be rolled back on a laptop will not roll back in production.

## Constraints

Add foreign keys and not-null constraints for new columns once the data allows it. Add check constraints in two steps on large tables: first create them without validating existing rows, then validate in a separate migration so the long scan does not hold a strict lock.
