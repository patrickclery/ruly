# Error Handling in Ruby

Errors are part of the interface of every method. Decide deliberately which failures a caller should handle and which should stop the program.

## Raise specific errors

Define an error hierarchy per component: a base class that inherits from StandardError and specific subclasses for each failure a caller might want to treat differently. Raise with a message that names the input that failed and what was expected.

```ruby
module Billing
  class Error < StandardError; end
  class InvalidAmount < Error; end
end
```

Never raise a bare string, and never raise Exception or rescue it. Rescuing Exception swallows interrupts and exit signals.

## Rescue narrowly

Rescue the most specific error you can handle, as close as possible to the call that raised it. A rescue block should either recover fully, translate the error into one that fits the caller's abstraction, or add context and re-raise. A rescue that only logs and continues hides bugs.

- Keep the begin block small so it is obvious which call can fail.
- Do not use exceptions for ordinary control flow such as a missing record that is expected half the time; return nil or a result object instead.
- When translating an error, pass the original as the cause so the backtrace survives.

## Retries

Retry only operations that are safe to repeat, such as reads and idempotent writes. Use a bounded number of attempts with exponential backoff and jitter, and log each retry at warn level. After the final attempt, raise the original error.

## External calls

Every call to another service has a timeout. A missing timeout turns a slow dependency into an outage of your own. Wrap client errors from third-party libraries in your component's error classes at the boundary so the rest of the code does not depend on the library's exception names.

## Background jobs

A job that fails should fail loudly and be safe to run again. Make jobs idempotent, record progress so a retry can resume, and send permanent failures to a dead-letter queue that someone reviews every week.

## Ensuring cleanup

Use ensure for cleanup that must happen whether or not an error occurred: closing files, releasing locks, deleting temporary records. Prefer block forms such as File.open with a block, which handle cleanup for you.
