# Database Queries

Queries are where most performance and correctness problems hide. Write them deliberately and check what they do.

## Use the query builder

Build queries with the query builder or the model layer, never by interpolating values into SQL strings. When raw SQL is unavoidable, use bound parameters for every value that comes from outside the code.

## Know what runs

Read the generated SQL for any non-trivial query, and run an explain on queries against large tables. Look for sequential scans on big tables, sorts that spill to disk and joins that multiply rows unexpectedly.

- Index the columns used in where clauses, joins and order by on large tables.
- Composite indexes follow the order of the conditions: equality columns first, then range columns.
- Remove indexes nobody uses; every index slows down writes.

## Loading data

- Select only the columns you need when rows are wide.
- Paginate any list that can grow without bound, using keyset pagination for deep pages.
- Preload associations to avoid the N plus one pattern.
- Process large result sets in batches instead of loading everything into memory.

## Transactions

Keep transactions short and never make network calls inside one. A transaction that waits on a remote service holds locks for as long as the service takes to answer. Use the strictest isolation level the operation needs, and retry on serialization failures.

## Counting and existence

Use an existence check instead of counting rows when you only need to know whether any exist. Cache expensive counts that are shown on every page.

## Reports

Heavy reporting queries run against a read replica, not the primary database, and have a statement timeout.

## Soft deletes

Tables that use soft deletes need the deleted flag in every query and in the relevant indexes. Use a default scope only when every caller wants it, and name the unscoped query explicitly when an admin view needs deleted rows. Purge soft-deleted rows on a schedule so tables do not grow forever.
