# Input Validation

All input from outside the process is untrusted: request parameters, headers, uploaded files, webhook payloads, messages from queues and data read back from third-party services.

## Validate at the boundary

Validate input where it enters the system, before it reaches business logic. Check type, length, format and range, and reject anything that does not match with a clear error message. Allow-lists beat deny-lists: describe what valid input looks like rather than trying to enumerate every bad value.

- Use strong parameter filtering so only expected fields reach the model.
- Parse numbers, dates and identifiers into typed values once, at the boundary.
- Limit the size of request bodies, uploaded files and collection parameters.

## Injection

Never build SQL, shell commands, file paths or HTML by concatenating untrusted input. Use bound parameters for queries, argument arrays instead of shell strings for subprocesses, and the template engine's escaping for HTML. When a user-supplied value names a file, resolve the path and check that it stays inside the expected directory.

## Authorization is not validation

Validating that an id is well formed does not mean the caller may access the record. Check ownership or permissions for every record loaded from a user-supplied identifier.

## Files

Check uploaded files by content, not by extension. Store them outside the web root with generated names, and scan them before processing.

## Errors

Validation errors tell the user what to fix without revealing internals. Do not echo raw input back in error pages without escaping it, and never include stack traces in responses.

## Webhooks

Verify the signature of every incoming webhook before reading its payload, and reject requests with old timestamps to prevent replay.

## Redirects

Never redirect to a URL taken directly from a request parameter. Accept only relative paths or a known list of hosts, and fall back to the home page when the value does not match. Open redirects make phishing links look trustworthy.
