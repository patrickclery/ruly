---
requires:
  - style.md
---
# Logging in Ruby Code

Logs are the first thing anyone reads during an incident. Write them for that reader: someone under time pressure who does not know your code.

## Where output goes

Library code never calls puts; write through the injected logger.

The command line layer is the only place that prints to standard output, because printing is its job. Everything below it receives a logger in its constructor, defaulting to the application logger, so tests can pass a null logger or a string buffer and assert on the lines written.

## Levels

- debug: details useful only while developing a feature. Off in production.
- info: one line per meaningful business event, such as an order placed or a job finished.
- warn: something unexpected that the code handled, such as a retry that succeeded.
- error: a failure that a person may need to act on. Every error line should be actionable.

Do not log the same failure at several layers. Log it once, where you have the most context, and let the exception carry the details upward.

## Structure

Log lines are structured key and value pairs, not prose sentences. Put the event name first, then the identifiers needed to find the record, then measurements.

```ruby
logger.info(event: 'invoice.sent', invoice_id: invoice.id, duration_ms: elapsed)
```

Include a request id or job id on every line so a single flow can be followed across services.

## What never goes in a log

Never log passwords, access tokens, full card numbers, session cookies or personal data beyond an internal user id. Filter parameters at the framework level so a new field does not leak by accident. When in doubt, log the length or a hash of a value rather than the value itself.

## Volume

A log line inside a loop over thousands of records will flood the pipeline. Log a summary after the loop instead: how many records were processed, how many were skipped and how long it took.
