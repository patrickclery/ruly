# Secrets

Secrets are credentials that grant access: passwords, API tokens, private keys, signing keys and database connection strings. Treat every one as if it were already leaked the moment it appears somewhere it should not.

## Storage

Secrets live in the secrets manager and reach the application through environment variables at runtime. Never commit a secret to the repository, not even to a private branch, a test file or a commented-out line. Example configuration files use obvious placeholders.

## Detection

The repository runs a secret scanner on every push. When it flags a value, assume the value is real until proven otherwise. A false positive is cheap to dismiss; a missed key is not.

## If a secret leaks

1. Revoke or rotate the secret immediately. Removing it from the repository is not enough, because history and forks keep a copy.
2. Check the provider's audit log for use of the secret since it leaked.
3. Open a security issue describing what leaked, when, for how long and what access it granted.
4. Remove the secret from the code and replace it with a reference to the secrets manager.

## Least privilege

Each service gets its own credentials with only the permissions it needs. Shared credentials make it impossible to tell which service did what, and impossible to rotate one without touching all of them.

## Rotation

Rotate secrets on a schedule and whenever someone with access leaves the team. Design services to pick up a new secret without a redeploy where possible.

## Logs and errors

Never print secrets in logs, error messages, exception reports or test output. Filter known secret fields at the logging layer, and review new log lines for values that could contain credentials.

## Local development

Developers use their own scoped credentials for local work, never production credentials. Local environment files are listed in the ignore file and are never shared in chat. When a new secret is needed locally, add a placeholder to the example file and document where to request the real value.
