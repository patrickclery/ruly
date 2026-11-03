---
name: deploy
description: Deploy the current main branch to production and verify the release.
---
# Deploy

Use this skill to deploy a build that has passed continuous integration on the main branch.

## Before deploying

- Confirm the build for the commit you are deploying is green.
- Check the team channel for a deploy freeze or an ongoing incident.
- Read the list of changes since the last deploy and note any migrations or feature flags.

## Deploying

Start the deploy from the pipeline, never from a laptop. Watch the rollout until every instance runs the new version. If the change includes a migration, confirm it finished before the new code takes traffic.

## Verifying

For fifteen minutes after the rollout, watch the error rate, latency and the key business metrics on the service dashboard. Open the main user flows in the browser and check that they work.

## Rolling back

If the error rate rises or a key flow breaks, roll back first and investigate second. Post in the team channel when you start and finish a rollback, and open an issue with what you saw.
