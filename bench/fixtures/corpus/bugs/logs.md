# Reading Logs During an Investigation

Logs answer the question "what did the system actually do?". Use them before guessing.

## Finding the right lines

Start from an identifier you know: a request id from an error report, a user id, an order number. Search for it across all services in the time window of the incident, and widen the window by a few minutes on each side because clocks and queues add delay.

- Filter by service and level first, then by identifier.
- Sort by timestamp and read the flow in order, from the first request to the error.
- Note gaps: a request that logs its start but never its end often points to a timeout or a crashed worker.

## Correlating

Follow the request id across service boundaries. When a service does not propagate the id, use timestamps and the record identifiers in the payload to connect the lines, and open an issue to add propagation.

## Patterns over single lines

One error line is an anecdote. Count how often the error happens, when it started and which hosts or customers are affected. A query that groups errors by message and by hour quickly shows whether a problem is new, growing or constant background noise.

## Recording evidence

Copy the relevant log lines into the issue, with timestamps and the query you used to find them, so others can rerun it. Redact tokens, email addresses and other personal data before pasting. Logs expire; the issue is the permanent record.

## When the logs are not enough

If you cannot answer a question from the logs, the logs are missing something. Add the line you wished you had, with the right identifiers, as part of the fix.

## Retention

Know how long each log stream is kept before you need it. If an investigation depends on lines that are about to expire, export the relevant slice to the issue or to cold storage first.
