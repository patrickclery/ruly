---
description: Create a Git branch for the current agent's JIRA ticket
alwaysApply: true
allowed-tools: [Bash, Read, mcp__atlassian__getJiraIssue]
---

# Create Git Branch for Agent {{AGENT_ID}}

I'll create a Git branch for this agent's JIRA ticket following the team's branch naming convention.

## Steps:

1. First, I'll read the agent ID from the environment
2. Fetch the JIRA issue details for the ticket
3. Determine the branch type based on the JIRA issue type
4. Select an appropriate domain (or use the one provided in arguments)
5. Process the JIRA title to create a valid branch name
6. Validate the branch name matches the required pattern
7. Create and checkout the new branch

## Branch Naming Rules:

See `@rules/pr/common.md#branch-naming-conventions` for format, regex pattern, and naming rules.

## Domain Override:

$ARGUMENTS

Please follow the rules documented in `.claude/BRANCH_NAMING.md` for the complete convention.

Let me start by fetching the JIRA issue details and creating the appropriate branch.
