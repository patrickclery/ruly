# Mattermost MCP Fork + Comms Rules Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fork the pvev/mattermost-mcp server and add DM channel support (mirroring the Teams MCP fork pattern), then create Ruly comms rules for Mattermost DMs with threaded conversations.

**Architecture:** Fork pvev/mattermost-mcp (TypeScript, MCP SDK), add tools for creating DM channels and sending DMs by user ID. Create `rules/comms/mattermost/` mirroring `rules/comms/ms-teams/` with commands, agents, and common config. Add Ruly recipe entries for the new MCP server and subagent.

**Tech Stack:** TypeScript, @modelcontextprotocol/sdk, Mattermost REST API v4, Ruly recipes (YAML)

---

## Pre-requisites

Before starting, you need:
- A Mattermost personal access token (or bot token) for testing
- The Mattermost instance URL (e.g., `https://mattermost.example.com`)
- Your Mattermost team ID and user ID

---

## Task 1: Fork pvev/mattermost-mcp on GitHub

**Files:** None (GitHub operation)

**Step 1: Fork the repository**

```bash
gh repo fork pvev/mattermost-mcp --clone=false --org="" --fork-name="mattermost-mcp"
```

This creates `patrickclery/mattermost-mcp` on GitHub (same pattern as `patrickclery/teams-mcp`).

**Step 2: Clone the fork locally**

```bash
cd ~/Projects
git clone git@github.com:patrickclery/mattermost-mcp.git
cd mattermost-mcp
git remote add upstream https://github.com/pvev/mattermost-mcp.git
```

**Step 3: Verify the clone**

Run: `ls src/tools/`
Expected: `channels.ts`, `messages.ts`, `users.ts`, `monitoring.ts`, `index.ts`

**Step 4: Install dependencies and build**

```bash
npm install
npm run build
```

Expected: Clean build with no errors.

**Step 5: Commit (nothing to commit - just verifying fork)**

---

## Task 2: Add `create_direct_channel` Tool

The pvev client already has a `createDirectMessageChannel()` method in `src/client.ts` but no tool exposes it. This task adds that tool.

**Files:**
- Modify: `src/tools/messages.ts` (add tool definition + handler)
- Modify: `src/tools/index.ts` (register new tool)

**Step 1: Write the failing test**

Create: `src/tools/__tests__/messages.test.ts`

```typescript
import { describe, it, expect, vi } from 'vitest';
import { handleCreateDirectChannel } from '../messages.js';

describe('handleCreateDirectChannel', () => {
  it('creates a DM channel and returns channel info', async () => {
    const mockClient = {
      createDirectMessageChannel: vi.fn().mockResolvedValue({
        id: 'dm-channel-123',
        type: 'D',
        display_name: '',
        name: 'user1__user2',
      }),
    };

    const result = await handleCreateDirectChannel(mockClient as any, {
      user_id: 'target-user-456',
    });

    expect(mockClient.createDirectMessageChannel).toHaveBeenCalledWith('target-user-456');
    expect(result.content[0].text).toContain('dm-channel-123');
    expect(result.isError).toBeUndefined();
  });

  it('returns error on failure', async () => {
    const mockClient = {
      createDirectMessageChannel: vi.fn().mockRejectedValue(new Error('Forbidden')),
    };

    const result = await handleCreateDirectChannel(mockClient as any, {
      user_id: 'target-user-456',
    });

    expect(result.isError).toBe(true);
    expect(result.content[0].text).toContain('Forbidden');
  });
});
```

**Step 2: Run test to verify it fails**

Run: `npx vitest run src/tools/__tests__/messages.test.ts`
Expected: FAIL - `handleCreateDirectChannel` is not exported from `../messages.js`

**Step 3: Write the tool definition and handler**

Add to `src/tools/messages.ts`:

```typescript
// Tool definition
export const createDirectChannelTool: Tool = {
  name: "mattermost_create_direct_channel",
  description: "Create or get an existing direct message channel with a user. Idempotent - returns existing DM channel if one already exists.",
  inputSchema: {
    type: "object",
    properties: {
      user_id: {
        type: "string",
        description: "The user ID to create a direct message channel with",
      },
    },
    required: ["user_id"],
  },
};

// Handler
export async function handleCreateDirectChannel(
  client: MattermostClient,
  args: { user_id: string }
) {
  const { user_id } = args;
  try {
    const channel = await client.createDirectMessageChannel(user_id);
    return {
      content: [
        {
          type: "text" as const,
          text: JSON.stringify(
            {
              id: channel.id,
              type: channel.type,
              name: channel.name,
              display_name: channel.display_name,
            },
            null,
            2
          ),
        },
      ],
    };
  } catch (error) {
    return {
      content: [
        {
          type: "text" as const,
          text: JSON.stringify({
            error: error instanceof Error ? error.message : String(error),
          }),
        },
      ],
      isError: true,
    };
  }
}
```

Register in `src/tools/index.ts` - add to imports, `tools` array, and `toolHandlers` map:

```typescript
import {
  // ...existing imports...
  createDirectChannelTool,
  handleCreateDirectChannel,
} from "./messages.js";

// Add to tools array
export const tools: Tool[] = [
  // ...existing tools...
  createDirectChannelTool,
];

// Add to toolHandlers map
export const toolHandlers: Record<string, Function> = {
  // ...existing handlers...
  mattermost_create_direct_channel: handleCreateDirectChannel,
};
```

**Step 4: Run test to verify it passes**

Run: `npx vitest run src/tools/__tests__/messages.test.ts`
Expected: PASS

**Step 5: Commit**

```bash
git add src/tools/messages.ts src/tools/index.ts src/tools/__tests__/messages.test.ts
git commit -m "feat: add create_direct_channel tool"
```

---

## Task 3: Add `send_direct_message` Convenience Tool

This combines creating/getting the DM channel and posting in one call — the key DM tool.

**Files:**
- Modify: `src/tools/messages.ts`
- Modify: `src/tools/index.ts`
- Modify: `src/tools/__tests__/messages.test.ts`

**Step 1: Write the failing test**

Add to `src/tools/__tests__/messages.test.ts`:

```typescript
import { handleSendDirectMessage } from '../messages.js';

describe('handleSendDirectMessage', () => {
  it('creates DM channel and sends message', async () => {
    const mockClient = {
      createDirectMessageChannel: vi.fn().mockResolvedValue({
        id: 'dm-channel-123',
        type: 'D',
      }),
      createPost: vi.fn().mockResolvedValue({
        id: 'post-789',
        channel_id: 'dm-channel-123',
        message: 'Hello there',
        create_at: Date.now(),
      }),
    };

    const result = await handleSendDirectMessage(mockClient as any, {
      user_id: 'target-user-456',
      message: 'Hello there',
    });

    expect(mockClient.createDirectMessageChannel).toHaveBeenCalledWith('target-user-456');
    expect(mockClient.createPost).toHaveBeenCalledWith('dm-channel-123', 'Hello there');
    expect(result.content[0].text).toContain('post-789');
    expect(result.isError).toBeUndefined();
  });

  it('supports root_id for threaded DMs', async () => {
    const mockClient = {
      createDirectMessageChannel: vi.fn().mockResolvedValue({
        id: 'dm-channel-123',
        type: 'D',
      }),
      createPost: vi.fn().mockResolvedValue({
        id: 'post-reply-1',
        channel_id: 'dm-channel-123',
        root_id: 'root-post-000',
        message: 'Thread reply',
        create_at: Date.now(),
      }),
    };

    const result = await handleSendDirectMessage(mockClient as any, {
      user_id: 'target-user-456',
      message: 'Thread reply',
      root_id: 'root-post-000',
    });

    expect(mockClient.createPost).toHaveBeenCalledWith(
      'dm-channel-123',
      'Thread reply',
      'root-post-000'
    );
    expect(result.isError).toBeUndefined();
  });
});
```

**Step 2: Run test to verify it fails**

Run: `npx vitest run src/tools/__tests__/messages.test.ts`
Expected: FAIL - `handleSendDirectMessage` not exported

**Step 3: Write the implementation**

Add to `src/tools/messages.ts`:

```typescript
export const sendDirectMessageTool: Tool = {
  name: "mattermost_send_direct_message",
  description: "Send a direct message to a user. Creates the DM channel if it doesn't exist. Supports threaded replies via root_id.",
  inputSchema: {
    type: "object",
    properties: {
      user_id: {
        type: "string",
        description: "The user ID to send the direct message to",
      },
      message: {
        type: "string",
        description: "The message text to send (supports markdown)",
      },
      root_id: {
        type: "string",
        description: "Optional. The post ID of the root message to reply to (creates a threaded reply)",
      },
    },
    required: ["user_id", "message"],
  },
};

export async function handleSendDirectMessage(
  client: MattermostClient,
  args: { user_id: string; message: string; root_id?: string }
) {
  const { user_id, message, root_id } = args;
  try {
    const channel = await client.createDirectMessageChannel(user_id);
    const post = await client.createPost(channel.id, message, root_id);
    return {
      content: [
        {
          type: "text" as const,
          text: JSON.stringify(
            {
              id: post.id,
              channel_id: post.channel_id,
              message: post.message,
              root_id: post.root_id || null,
              create_at: new Date(post.create_at).toISOString(),
              dm_with_user: user_id,
            },
            null,
            2
          ),
        },
      ],
    };
  } catch (error) {
    return {
      content: [
        {
          type: "text" as const,
          text: JSON.stringify({
            error: error instanceof Error ? error.message : String(error),
          }),
        },
      ],
      isError: true,
    };
  }
}
```

**Important:** Check if `client.createPost()` already accepts an optional `root_id` parameter. If not, modify `src/client.ts`:

```typescript
// In MattermostClient class
async createPost(channelId: string, message: string, rootId?: string): Promise<Post> {
  const url = `${this.baseUrl}/posts`;
  const body: Record<string, string> = { channel_id: channelId, message };
  if (rootId) {
    body.root_id = rootId;
  }
  const response = await fetch(url, {
    method: 'POST',
    headers: this.headers,
    body: JSON.stringify(body),
  });
  if (!response.ok) {
    throw new Error(`Failed to create post: ${response.status} ${response.statusText}`);
  }
  return response.json() as Promise<Post>;
}
```

Register in `src/tools/index.ts` (same pattern as Task 2).

**Step 4: Run test to verify it passes**

Run: `npx vitest run src/tools/__tests__/messages.test.ts`
Expected: PASS

**Step 5: Commit**

```bash
git add src/tools/messages.ts src/tools/index.ts src/client.ts src/tools/__tests__/messages.test.ts
git commit -m "feat: add send_direct_message tool with thread support"
```

---

## Task 4: Add `get_direct_channel_posts` Tool

For reading DM conversation history (needed by the `details` command pattern).

**Files:**
- Modify: `src/tools/messages.ts`
- Modify: `src/tools/index.ts`
- Modify: `src/tools/__tests__/messages.test.ts`

**Step 1: Write the failing test**

Add to `src/tools/__tests__/messages.test.ts`:

```typescript
import { handleGetDirectChannelPosts } from '../messages.js';

describe('handleGetDirectChannelPosts', () => {
  it('fetches posts from a DM channel', async () => {
    const mockClient = {
      createDirectMessageChannel: vi.fn().mockResolvedValue({
        id: 'dm-channel-123',
        type: 'D',
      }),
      getChannelPosts: vi.fn().mockResolvedValue({
        order: ['post-1', 'post-2'],
        posts: {
          'post-1': { id: 'post-1', message: 'Hello', create_at: Date.now() },
          'post-2': { id: 'post-2', message: 'Hi', create_at: Date.now() },
        },
      }),
    };

    const result = await handleGetDirectChannelPosts(mockClient as any, {
      user_id: 'target-user-456',
    });

    expect(mockClient.createDirectMessageChannel).toHaveBeenCalledWith('target-user-456');
    expect(mockClient.getChannelPosts).toHaveBeenCalledWith('dm-channel-123', 30);
    expect(result.isError).toBeUndefined();
  });
});
```

**Step 2: Run test to verify it fails**

Run: `npx vitest run src/tools/__tests__/messages.test.ts`
Expected: FAIL

**Step 3: Write the implementation**

Add to `src/tools/messages.ts`:

```typescript
export const getDirectChannelPostsTool: Tool = {
  name: "mattermost_get_direct_channel_posts",
  description: "Get recent posts from a direct message conversation with a user.",
  inputSchema: {
    type: "object",
    properties: {
      user_id: {
        type: "string",
        description: "The user ID whose DM channel to read",
      },
      per_page: {
        type: "number",
        description: "Number of posts to retrieve (default: 30)",
      },
    },
    required: ["user_id"],
  },
};

export async function handleGetDirectChannelPosts(
  client: MattermostClient,
  args: { user_id: string; per_page?: number }
) {
  const { user_id, per_page = 30 } = args;
  try {
    const channel = await client.createDirectMessageChannel(user_id);
    const posts = await client.getChannelPosts(channel.id, per_page);
    return {
      content: [
        {
          type: "text" as const,
          text: JSON.stringify(posts, null, 2),
        },
      ],
    };
  } catch (error) {
    return {
      content: [
        {
          type: "text" as const,
          text: JSON.stringify({
            error: error instanceof Error ? error.message : String(error),
          }),
        },
      ],
      isError: true,
    };
  }
}
```

**Note:** Verify that `client.getChannelPosts()` exists. If the method is named differently (e.g., `getChannelHistory`), adjust accordingly. The Mattermost API endpoint is `GET /api/v4/channels/{channel_id}/posts`.

Register in `src/tools/index.ts`.

**Step 4: Run test to verify it passes**

Run: `npx vitest run src/tools/__tests__/messages.test.ts`
Expected: PASS

**Step 5: Commit**

```bash
git add src/tools/messages.ts src/tools/index.ts src/tools/__tests__/messages.test.ts
git commit -m "feat: add get_direct_channel_posts tool"
```

---

## Task 5: Add `search_users` Tool Enhancement (search by username)

The existing `mattermost_get_users` is paginated and not searchable. Add a search tool for finding users by name/username (needed for the DM command to resolve recipients).

**Files:**
- Modify: `src/tools/users.ts`
- Modify: `src/tools/index.ts`
- Modify: `src/client.ts` (add search method if missing)

**Step 1: Write the failing test**

Create: `src/tools/__tests__/users.test.ts`

```typescript
import { describe, it, expect, vi } from 'vitest';
import { handleSearchUsers } from '../users.js';

describe('handleSearchUsers', () => {
  it('searches users by term', async () => {
    const mockClient = {
      searchUsers: vi.fn().mockResolvedValue([
        { id: 'user-1', username: 'jdoe', first_name: 'John', last_name: 'Doe' },
      ]),
    };

    const result = await handleSearchUsers(mockClient as any, { term: 'jdoe' });

    expect(mockClient.searchUsers).toHaveBeenCalledWith('jdoe');
    expect(result.content[0].text).toContain('jdoe');
  });
});
```

**Step 2: Run test to verify it fails**

Run: `npx vitest run src/tools/__tests__/users.test.ts`
Expected: FAIL

**Step 3: Write the implementation**

Add `searchUsers` to `src/client.ts` if not present:

```typescript
async searchUsers(term: string): Promise<User[]> {
  const url = `${this.baseUrl}/users/search`;
  const response = await fetch(url, {
    method: 'POST',
    headers: this.headers,
    body: JSON.stringify({ term }),
  });
  if (!response.ok) {
    throw new Error(`Failed to search users: ${response.status}`);
  }
  return response.json() as Promise<User[]>;
}
```

Add tool in `src/tools/users.ts`:

```typescript
export const searchUsersTool: Tool = {
  name: "mattermost_search_users",
  description: "Search for users by username, first name, last name, or email.",
  inputSchema: {
    type: "object",
    properties: {
      term: {
        type: "string",
        description: "The search term (matches username, first_name, last_name, email)",
      },
    },
    required: ["term"],
  },
};

export async function handleSearchUsers(
  client: MattermostClient,
  args: { term: string }
) {
  try {
    const users = await client.searchUsers(args.term);
    return {
      content: [
        {
          type: "text" as const,
          text: JSON.stringify(
            users.map((u) => ({
              id: u.id,
              username: u.username,
              first_name: u.first_name,
              last_name: u.last_name,
              email: u.email,
            })),
            null,
            2
          ),
        },
      ],
    };
  } catch (error) {
    return {
      content: [
        {
          type: "text" as const,
          text: JSON.stringify({
            error: error instanceof Error ? error.message : String(error),
          }),
        },
      ],
      isError: true,
    };
  }
}
```

Register in `src/tools/index.ts`.

**Step 4: Run test to verify it passes**

Run: `npx vitest run src/tools/__tests__/users.test.ts`
Expected: PASS

**Step 5: Commit**

```bash
git add src/client.ts src/tools/users.ts src/tools/index.ts src/tools/__tests__/users.test.ts
git commit -m "feat: add search_users tool"
```

---

## Task 6: Build, test end-to-end, and push the fork

**Files:** None (operations only)

**Step 1: Run full test suite**

```bash
cd ~/Projects/mattermost-mcp
npx vitest run
```

Expected: All tests pass.

**Step 2: Build**

```bash
npm run build
```

Expected: Clean build, no errors.

**Step 3: Manual smoke test with MCP inspector (optional)**

```bash
npx @modelcontextprotocol/inspector node dist/index.js
```

Verify the new tools appear in the tools list:
- `mattermost_create_direct_channel`
- `mattermost_send_direct_message`
- `mattermost_get_direct_channel_posts`
- `mattermost_search_users`

**Step 4: Push to fork**

```bash
git push origin main
```

**Step 5: Commit (nothing to commit - just pushed)**

---

## Task 7: Configure MCP Server in Claude Code

**Files:**
- Modify: `~/.claude/settings.json` or project `.mcp.json` (wherever MCP servers are configured)

**Step 1: Read the current MCP config**

Read the file where your MCP servers are configured (e.g., `~/.claude.json`, `.mcp.json`, or VS Code `settings.json`).

**Step 2: Add the Mattermost MCP server entry**

```json
{
  "mattermost": {
    "command": "node",
    "args": ["/Users/patrick/Projects/mattermost-mcp/dist/index.js"],
    "env": {}
  }
}
```

Note: The pvev server uses `config.local.json` in the project root for auth. Create it:

```json
{
  "mattermostUrl": "https://YOUR_INSTANCE.com/api/v4",
  "token": "YOUR_PERSONAL_ACCESS_TOKEN",
  "teamId": "YOUR_TEAM_ID"
}
```

**Step 3: Verify MCP server loads**

Restart Claude Code and verify the mattermost tools appear. Run any simple tool like `mattermost_get_users` to confirm connectivity.

**Step 4: Commit (no code to commit - config only)**

---

## Task 8: Create `rules/comms/mattermost/common.md`

**Files:**
- Create: `rules/comms/mattermost/common.md`

**Step 1: Create the common configuration file**

```markdown
---
description: Common Mattermost patterns and references
alwaysApply: false
---

# Mattermost Common Patterns

## MCP Server

**Using forked server:** [patrickclery/mattermost-mcp](https://github.com/patrickclery/mattermost-mcp)

This fork adds DM channel creation, direct messaging, and DM history tools over the upstream pvev/mattermost-mcp server.

## Message Format

Mattermost supports markdown natively in all messages. URLs are automatically converted to clickable hyperlinks.

## Mattermost @Mentions

For @mentions to work in Mattermost, use the `@username` syntax directly in the message text. Unlike Teams, Mattermost does not require a separate mentions parameter.

```
mcp__mattermost__mattermost_post_message with:
- channel_id: "..."
- message: "Hi @jdoe, please review this PR"
```

## Direct Messages

### Sending a DM

Use `mattermost_send_direct_message` which handles DM channel creation automatically:

```javascript
mcp__mattermost__mattermost_send_direct_message with:
- user_id: "{mattermost_user_id}"
- message: "Can you review PR #456?"
```

### Threaded DM Replies

Mattermost supports threads in DMs (unlike Teams). To reply in a thread:

```javascript
mcp__mattermost__mattermost_send_direct_message with:
- user_id: "{mattermost_user_id}"
- message: "Thread reply here"
- root_id: "{root_post_id}"
```

### Reading DM History

```javascript
mcp__mattermost__mattermost_get_direct_channel_posts with:
- user_id: "{mattermost_user_id}"
- per_page: 30
```

## Thread Replies in Channels

```javascript
mcp__mattermost__mattermost_reply_to_thread with:
- channel_id: "{channel_id}"
- post_id: "{root_post_id}"
- message: "Reply content"
```

## Searching for Users

```javascript
mcp__mattermost__mattermost_search_users with:
- term: "jdoe"
```

## Looking Up Mattermost IDs

Mattermost user IDs and usernames are stored in [Team Directory](#team-directory) under the "Mattermost ID" and "Mattermost Username" columns.

If a user is not found in the directory, search using:

```javascript
mcp__mattermost__mattermost_search_users with:
- term: "First Last"
```
```

**Step 2: Commit**

```bash
git add rules/comms/mattermost/common.md
git commit -m "feat: add Mattermost common patterns rule"
```

---

## Task 9: Create `rules/comms/mattermost/agents/mattermost-dm.md`

**Files:**
- Create: `rules/comms/mattermost/agents/mattermost-dm.md`

**Step 1: Create the subagent execution rule**

Mirror the Teams DM subagent pattern from `rules/comms/ms-teams/agents/ms-teams-dm.md`:

```markdown
---
description: Instructions for the mattermost_dm subagent when dispatched to send a direct message
alwaysApply: true
requires:
  - ../accounts.md
  - common.md
---

# Mattermost DM Subagent - EXECUTION REQUIRED

## CRITICAL: You MUST Execute MCP Calls

**Your ONLY job is to send the Mattermost message.** If you complete with "0 tool uses", you have FAILED.

You have `permissionMode: bypassPermissions` - you CAN and MUST make MCP calls.

## Input Format

You will receive a prompt like:

```
Send Mattermost DM:
- Recipient: {Full Name}
- Mattermost User ID: {user_id}
- Message: {the message to send}
- Thread Root ID: {root_post_id or "none"}
```

## Execution Steps

### Step 1: Send the Message

```javascript
mcp__mattermost__mattermost_send_direct_message with:
- user_id: "{mattermost_user_id}"
- message: "{the message}"
- root_id: "{root_post_id}"  // Only if Thread Root ID is not "none"
```

### Step 2: Return Result

**On success:**
```json
{
  "status": "sent",
  "recipient": "{Full Name}",
  "post_id": "{post_id from response}",
  "channel_id": "{channel_id from response}",
  "threaded": true/false
}
```

**On error:**
```json
{
  "status": "error",
  "error": "{error message}",
  "step": "{which step failed}"
}
```

## Failure Conditions

- FAILED if you complete with "0 tool uses"
- FAILED if you return without making MCP calls
- FAILED if you ask clarifying questions instead of executing

## Team Directory Reference

Mattermost IDs are in [Team Directory](#team-directory).
```

**Step 2: Commit**

```bash
git add rules/comms/mattermost/agents/mattermost-dm.md
git commit -m "feat: add Mattermost DM subagent rule"
```

---

## Task 10: Create `rules/comms/mattermost/commands/dm.md`

**Files:**
- Create: `rules/comms/mattermost/commands/dm.md`

**Step 1: Create the user-facing DM command**

Mirror `rules/comms/ms-teams/commands/dm.md`:

```markdown
---
description: Draft and send direct messages via Mattermost
alwaysApply: false
requires:
  - ../common.md
  - ../../jira/preview-common.md
  - ../../accounts.md
---

# Mattermost Direct Message

## Overview

Draft a direct message to a team member via Mattermost. Follows a draft-first workflow - preview before sending. Supports threaded DM conversations.

## Usage

```
/mattermost:dm <first or full name> <message>
```

## Workflow

### Step 1: Resolve Recipient

Look up the recipient in [Team Directory](#team-directory):

1. Search by first name or full name (case-insensitive)
2. If multiple matches, ask user to clarify
3. If no match found, search via MCP as fallback

**Required fields from Team Directory:**
- Full Name
- Mattermost User ID

### Step 2: Preview Draft

Follow [Jira Draft Preview Workflow](#jira-draft-preview-workflow) patterns:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
DRAFT MATTERMOST DM to {Full Name}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

{Your message appears here}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Type "send it" to deliver this message
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Step 3: Handle Response

**ONLY "send it" triggers sending** (case-insensitive):
- "send it" / "Send it" / "SEND IT" -> Proceed to Step 4

**Everything else = revision request.**

### Step 4: Dispatch Subagent

When user confirms with "send it", dispatch the `mattermost_dm` subagent:

```
Task tool:
  subagent_type: "mattermost_dm"
  prompt: |
    Send Mattermost DM:
    - Recipient: {Full Name}
    - Mattermost User ID: {user_id from Team Directory}
    - Message: {the confirmed message}
    - Thread Root ID: none
```

### Step 5: Show Result

**On success:**
```
Message sent to {Full Name}!
   Post ID: {post_id}
```

**On error:**
```
Failed to send message: {error}
```

## Threaded Replies

To reply in an existing DM thread, include the root post ID:

```
/mattermost:dm:reply <name> <root_post_id> <message>
```

The subagent dispatch includes `Thread Root ID: {root_post_id}` instead of "none".

## Error Handling

| Error | Action |
|-------|--------|
| Recipient not found | Report error, suggest checking spelling |
| MCP call failed | Show error details from subagent response |
```

**Step 2: Commit**

```bash
git add rules/comms/mattermost/commands/dm.md
git commit -m "feat: add Mattermost DM command rule"
```

---

## Task 11: Add Mattermost columns to Team Directory (`accounts.md`)

**Files:**
- Modify: `rules/comms/accounts.md`

**Step 1: Read the current accounts.md table headers**

Read `rules/comms/accounts.md` and identify the table header row.

**Step 2: Add Mattermost columns**

Add two new columns to the Team Directory table:
- `Mattermost Username`
- `Mattermost ID`

Update the header row:
```
| Name | Role | Jira Account ID | GitHub | MS Teams ID | MS Teams Chat ID | Mattermost Username | Mattermost ID |
```

Leave the Mattermost columns empty for now — they'll be populated as team members are onboarded to Mattermost.

**Step 3: Commit**

```bash
git add rules/comms/accounts.md
git commit -m "feat: add Mattermost columns to Team Directory"
```

---

## Task 12: Add Mattermost recipes to `recipes.yml`

**Files:**
- Modify: `/Users/patrick/Projects/ruly/recipes.yml`
- Modify: `/Users/patrick/.config/ruly/recipes.yml` (must match)

**Step 1: Read current recipes.yml**

Already read above.

**Step 2: Add Mattermost subagent recipe**

Add after the `ms-teams-dm` recipe:

```yaml
  mattermost-dm:
    description: "Send a Mattermost DM (subagent execution)"
    files:
      - /Users/patrick/Projects/ruly/rules/comms/mattermost/agents/mattermost-dm.md
      - /Users/patrick/Projects/ruly/rules/comms/mattermost/common.md
      - /Users/patrick/Projects/ruly/rules/comms/accounts.md
    mcp_servers:
      - mattermost  # For Mattermost MCP calls
```

**Step 3: Add `mattermost_dm` subagent to recipes that have `ms_teams_dm`**

For each recipe that currently lists `ms_teams_dm` as a subagent (full, jira, comms, agile), add:

```yaml
      - name: mattermost_dm
        recipe: mattermost-dm
```

And add `- mattermost` to their `mcp_servers` list.

**Step 4: Copy to user config**

```bash
cp /Users/patrick/Projects/ruly/recipes.yml /Users/patrick/.config/ruly/recipes.yml
```

**Step 5: Commit**

```bash
git add recipes.yml
git commit -m "feat: add Mattermost DM recipes and subagent config"
```

---

## Task 13: Update README.md with Mattermost commands

**Files:**
- Modify: `README.md`

**Step 1: Read README.md slash commands section**

Find the section listing available slash commands.

**Step 2: Add Mattermost commands**

Add entries for:
- `/mattermost:dm` - Send a direct message via Mattermost
- `/mattermost:dm:reply` - Reply in a DM thread

**Step 3: Commit**

```bash
git add README.md
git commit -m "docs: add Mattermost commands to README"
```

---

## Summary

| Task | Description | Repo |
|------|-------------|------|
| 1 | Fork pvev/mattermost-mcp | GitHub |
| 2 | Add `create_direct_channel` tool | mattermost-mcp |
| 3 | Add `send_direct_message` tool (with threads) | mattermost-mcp |
| 4 | Add `get_direct_channel_posts` tool | mattermost-mcp |
| 5 | Add `search_users` tool | mattermost-mcp |
| 6 | Build, test, push fork | mattermost-mcp |
| 7 | Configure MCP server in Claude Code | config |
| 8 | Create `common.md` rule | ruly/rules |
| 9 | Create DM subagent rule | ruly/rules |
| 10 | Create DM command rule | ruly/rules |
| 11 | Add Mattermost columns to accounts.md | ruly/rules |
| 12 | Add recipes for Mattermost | ruly |
| 13 | Update README.md | ruly |

**New tools added to fork:** `mattermost_create_direct_channel`, `mattermost_send_direct_message`, `mattermost_get_direct_channel_posts`, `mattermost_search_users`

**Key advantage over Teams:** Threaded DM conversations via `root_id` parameter — works identically in channels and DMs.
