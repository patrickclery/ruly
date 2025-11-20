# Setting Up Task Master with Claude Max Proxy

This guide explains how to configure Task Master to work with the Claude Max Proxy, allowing you to use your Claude Pro/Max subscription without needing a separate API key.

## Prerequisites

1. **Claude Pro or Max subscription**
2. **Claude Max Proxy running** at `http://localhost:8081`
   - See [anthropic-claude-max-proxy](https://github.com/Pimzino/anthropic-claude-max-proxy/) for setup
3. **Task Master installed**
   ```bash
   npm install -g @eyaltoledano/claude-task-master
   ```

## Configuration Steps

### 1. Initialize Task Master Project

If you haven't already initialized Task Master in your project:

```bash
task-master init
```

This creates `.taskmaster/` directory with default configuration.

### 2. Get Your Proxy API Key

Your Claude Max Proxy generates a unique API key when you set it up. You can find it in your proxy's configuration or by checking the proxy logs when it starts.

Example key format: `your-proxy-api-key-here` (a long alphanumeric string with special characters)

### 3. Configure `.taskmaster/config.json`

Edit `.taskmaster/config.json` with the following configuration:

```json
{
  "models": {
    "main": {
      "provider": "anthropic",
      "modelId": "claude-sonnet-4-20250514",
      "maxTokens": 64000,
      "temperature": 0.2,
      "baseURL": "http://localhost:8081/v1"
    },
    "research": {
      "provider": "anthropic",
      "modelId": "claude-sonnet-4-20250514",
      "maxTokens": 64000,
      "temperature": 0.1,
      "baseURL": "http://localhost:8081/v1"
    },
    "fallback": {
      "provider": "anthropic",
      "modelId": "claude-3-7-sonnet-20250219",
      "maxTokens": 64000,
      "temperature": 0.2,
      "baseURL": "http://localhost:8081/v1"
    }
  },
  "global": {
    "logLevel": "info",
    "debug": false,
    "defaultNumTasks": 10,
    "defaultSubtasks": 5,
    "defaultPriority": "medium",
    "projectName": "YourProjectName",
    "responseLanguage": "English",
    "enableCodebaseAnalysis": true,
    "defaultTag": "master",
    "userId": "your-user-id"
  },
  "anthropic": {
    "apiKey": "YOUR_PROXY_API_KEY_HERE"
  },
  "commandSpecific": {
    "parse-prd": {
      "maxTurns": 10,
      "customSystemPrompt": "You are a task breakdown specialist"
    }
  }
}
```

### 4. Key Configuration Points

**IMPORTANT**: Use the `anthropic` provider, NOT `claude-code` provider.

- **Provider**: Must be `"anthropic"` (not `"claude-code"`)
- **Base URL**: `"http://localhost:8081/v1"` (your proxy URL)
- **API Key**: Your proxy's API key in the `anthropic` section
- **Model IDs**: Use full Anthropic model names:
  - `claude-sonnet-4-20250514` (recommended for main/research)
  - `claude-opus-4-20250514` (more expensive but higher quality)
  - `claude-3-7-sonnet-20250219` (good for fallback)

### 5. Verify Proxy is Running

Before using Task Master, ensure your proxy is running:

```bash
curl http://localhost:8081/health
```

You should see a response (even if it says "Not Found", the proxy is running).

### 6. Test the Setup

Test with a simple command:

```bash
task-master models
```

This should show your configured models without errors.

## Using Task Master with the Proxy

### Parse a PRD

```bash
task-master parse-prd --input path/to/prd.txt
```

### Common Commands

```bash
# List all tasks
task-master list

# Show next task to work on
task-master next

# View specific task details
task-master show <task-id>

# Mark task as in progress
task-master set-status --id=<task-id> --status=in-progress

# Expand a task into subtasks
task-master expand --id=<task-id>

# Mark task as complete
task-master set-status --id=<task-id> --status=done
```

## Troubleshooting

### Error: "invalid x-api-key"

**Problem**: The API key in your config doesn't match the proxy's key.

**Solution**:

1. Check your proxy logs for the correct API key
2. Update the `anthropic.apiKey` field in `.taskmaster/config.json`

### Error: "Claude Code process exited with code 1"

**Problem**: You're using `claude-code` provider instead of `anthropic`.

**Solution**: Change all `"provider": "claude-code"` to `"provider": "anthropic"` in your config.

### Error: Connection refused to localhost:8081

**Problem**: The Claude Max Proxy is not running.

**Solution**:

1. Start your Claude Max Proxy
2. Verify it's listening on port 8081
3. Check there are no firewall issues

### Tasks not generating / Empty responses

**Problem**: Model ID might be incorrect or proxy not authenticated.

**Solution**:

1. Verify you're logged into Claude.ai in your browser
2. Re-run the proxy authentication: `python cli.py` → option 2 (Login)
3. Check that model IDs match supported models (use full names like `claude-sonnet-4-20250514`)

## Cost Tracking

Task Master will show approximate costs for each operation:

```
╭───────────────── 💡 Telemetry ─────────────────╮
│                                                │
│   AI Usage Summary:                            │
│     Command: parse-prd                         │
│     Provider: anthropic                        │
│     Model: claude-sonnet-4-20250514            │
│     Tokens: 7860 (Input: 5015, Output: 2845)   │
│     Est. Cost: $0.057720                       │
│                                                │
╰────────────────────────────────────────────────╯
```

**Note**: When using the Claude Max Proxy, these costs are estimates based on Anthropic's pricing, but you're actually using your Claude Pro/Max subscription, so there's no additional charge.

## Best Practices

1. **Keep proxy running**: Start the proxy before using Task Master
2. **Use debug mode**: Set `"debug": true` in global config when troubleshooting
3. **Monitor token usage**: Even though it's "free" via subscription, be mindful of usage
4. **Update models**: Use the latest model IDs for best performance
5. **Back up tasks**: The `.taskmaster/tasks/` directory contains your task data

## References

- [Task Master Documentation](https://github.com/eyaltoledano/claude-task-master)
- [Claude Max Proxy](https://github.com/Pimzino/anthropic-claude-max-proxy/)
- [Task Master Claude Code Usage](https://github.com/eyaltoledano/claude-task-master/blob/main/docs/examples/claude-code-usage.md)

## Example Working Configuration

Here's a minimal working `.taskmaster/config.json`:

```json
{
  "models": {
    "main": {
      "provider": "anthropic",
      "modelId": "claude-sonnet-4-20250514",
      "maxTokens": 64000,
      "temperature": 0.2,
      "baseURL": "http://localhost:8081/v1"
    }
  },
  "global": {
    "projectName": "MyProject",
    "defaultNumTasks": 10
  },
  "anthropic": {
    "apiKey": "your-proxy-api-key-here"
  }
}
```

This minimal config is enough to get started. You can add `research` and `fallback` models later as needed.
