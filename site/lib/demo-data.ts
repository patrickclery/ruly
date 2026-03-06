export interface DemoFile {
  path: string;
  content: string;
  language: "markdown" | "yaml" | "json" | "bash";
  annotations: { line: number; text: string }[];
}

export interface MenuOption {
  key: string;
  label: string;
  fileKey: string;
}

export const PWD_OUTPUT = "/Users/you/agents/orchestrator";

export const LS_OUTPUT = [
  { text: "total 24", color: "text-gray-400" },
  { text: "drwxr-xr-x   6 you  staff   192 Mar  6 14:22 ", color: "text-gray-400", suffix: ".", suffixColor: "text-blue-400 font-bold" },
  { text: "drwxr-xr-x   4 you  staff   128 Mar  6 14:20 ", color: "text-gray-400", suffix: "..", suffixColor: "text-blue-400 font-bold" },
  { text: "drwxr-xr-x   8 you  staff   256 Mar  6 14:22 ", color: "text-gray-400", suffix: "acme-api/", suffixColor: "text-blue-400 font-bold" },
  { text: "drwxr-xr-x   6 you  staff   192 Mar  6 14:22 ", color: "text-gray-400", suffix: "acme-web/", suffixColor: "text-blue-400 font-bold" },
  { text: "-rw-r--r--   1 you  staff   842 Mar  6 14:20 ", color: "text-gray-400", suffix: "profiles.yml", suffixColor: "text-white" },
  { text: "-rw-r--r--   1 you  staff    47 Mar  6 14:20 ", color: "text-gray-400", suffix: ".gitmodules", suffixColor: "text-white" },
];

export const TREE_OUTPUT = `~/agents/orchestrator/
├── CLAUDE.local.md              # Generated orchestrator rules
├── .mcp.json                    # MCP servers (collected from all subagents)
├── .claude/
│   ├── agents/
│   │   ├── backend_engineer.md  # Has acme-api's CLAUDE.md + hooks baked in
│   │   ├── frontend_engineer.md # Has acme-web's CLAUDE.md + rules + hooks baked in
│   │   └── comms.md             # Pure ruly profile (no repo append)
│   ├── scripts/
│   │   └── worktree-create.sh   # Propagated to all submodule dirs
│   └── settings.local.json      # Parent hooks (WorktreeCreate)
├── acme-api/                    # Backend repo (git submodule)
│   ├── CLAUDE.md                # 1800-line repo-specific guidance
│   └── .claude/
│       └── settings.json        # No custom hooks
├── acme-web/                    # Frontend repo (git submodule)
│   ├── CLAUDE.md                # 500-line repo-specific guidance
│   └── .claude/
│       ├── rules/
│       │   └── command-timeouts.md  # Repo-specific rules
│       ├── hooks/
│       │   └── eslint-fix.sh        # Repo-specific hook script
│       └── settings.json            # PostToolUse hook for ESLint`;

export const SQUASH_COMMAND = "ruly squash orchestrator";

export const SQUASH_OUTPUT = `Squashing profile: orchestrator
  Reading: rules/orchestrator/dispatch.md
  Subagent: backend_engineer (profile: backend-engineer, cwd: acme-api, append: true)
    Appending: acme-api/CLAUDE.md → Repository Context
    Appending: acme-api/.claude/rules/*.md → Repository Rules
    Merging:   acme-api/.claude/settings.json → hooks
  Subagent: frontend_engineer (profile: frontend-engineer, cwd: acme-web, append: true)
    Appending: acme-web/CLAUDE.md → Repository Context
    Appending: acme-web/.claude/rules/*.md → Repository Rules
    Merging:   acme-web/.claude/settings.json → hooks
  Subagent: comms (profile: comms)
  Copying:  scripts/worktree-create.sh → .claude/scripts/
  Writing:  CLAUDE.local.md (2,847 tokens)
  Writing:  .claude/agents/backend_engineer.md (4,102 tokens)
  Writing:  .claude/agents/frontend_engineer.md (2,356 tokens)
  Writing:  .claude/agents/comms.md (891 tokens)
  Writing:  .claude/settings.local.json
  Writing:  .mcp.json (3 servers)

Done. 6 files written to ~/agents/orchestrator/`;

export const MENU_OPTIONS: MenuOption[] = [
  { key: "1", label: "View CLAUDE.local.md", fileKey: "claude-local" },
  { key: "2", label: "View agents/backend_engineer.md", fileKey: "backend-agent" },
  { key: "3", label: "View agents/frontend_engineer.md", fileKey: "frontend-agent" },
  { key: "4", label: "View .mcp.json", fileKey: "mcp-json" },
  { key: "5", label: "View the profile YAML", fileKey: "profile-yaml" },
];

export const FILES: Record<string, DemoFile> = {
  "claude-local": {
    path: "CLAUDE.local.md",
    language: "markdown",
    content: `# Orchestrator Rules

## Dispatch Rules
- Route backend tasks to \`backend_engineer\`
- Route frontend tasks to \`frontend_engineer\`
- Route comms/notifications to \`comms\`

## Constraints
- Never run database migrations without confirmation
- Always create feature branches, never commit to main
- Use worktrees for parallel work across repos`,
    annotations: [
      { line: 1, text: "Generated from rules/orchestrator/dispatch.md" },
    ],
  },
  "backend-agent": {
    path: ".claude/agents/backend_engineer.md",
    language: "markdown",
    content: `---
description: "Backend engineer for acme-api"
hooks:
  PostToolUse: []
---

# Backend Engineer

You work in the acme-api repository.

## Repository Context

This is a Ruby on Rails API application using Sequel ORM.
Database: PostgreSQL 15. Test framework: RSpec.
Always run \\\`bundle exec rspec\\\` before committing.
...

## Repository Rules

(content from acme-api/.claude/rules/*.md)`,
    annotations: [
      { line: 3, text: "Merged from acme-api/.claude/settings.json" },
      { line: 9, text: "Generated from profile: backend-engineer" },
      { line: 13, text: "Appended from acme-api/CLAUDE.md" },
    ],
  },
  "frontend-agent": {
    path: ".claude/agents/frontend_engineer.md",
    language: "markdown",
    content: `---
description: "Frontend engineer for acme-web"
hooks:
  PostToolUse:
    - matcher: "Edit|Write"
      hooks:
        - type: command
          command: ".claude/hooks/eslint-fix.sh $FILE_PATH"
---

# Frontend Engineer

You work in the acme-web repository.

## Repository Context

Next.js 14 application with TypeScript and Tailwind CSS.
Always run \\\`npm run lint\\\` and \\\`npm test\\\` before committing.
...

## Repository Rules

### Command Timeouts
All npm commands have a 120s timeout. Use --verbose for builds.`,
    annotations: [
      { line: 4, text: "Merged from acme-web/.claude/settings.json" },
      { line: 7, text: "Hook script from acme-web/.claude/hooks/eslint-fix.sh" },
      { line: 15, text: "Appended from acme-web/CLAUDE.md" },
      { line: 22, text: "Appended from acme-web/.claude/rules/command-timeouts.md" },
    ],
  },
  "mcp-json": {
    path: ".mcp.json",
    language: "json",
    content: `{
  "mcpServers": {
    "task-master-ai": {
      "command": "npx",
      "args": ["-y", "task-master-ai"]
    },
    "teams": {
      "command": "npx",
      "args": ["-y", "@anthropic/teams-mcp"]
    },
    "playwright": {
      "command": "npx",
      "args": ["-y", "@anthropic/playwright-mcp"]
    }
  }
}`,
    annotations: [
      { line: 1, text: "Collected from all subagent profiles" },
      { line: 3, text: "From backend-engineer profile" },
      { line: 7, text: "From comms profile" },
      { line: 11, text: "From frontend-engineer profile" },
    ],
  },
  "profile-yaml": {
    path: "profiles.yml",
    language: "yaml",
    content: `profiles:
  orchestrator:
    description: "Multi-repo dispatcher"
    hooks:
      WorktreeCreate:
        - hooks:
            - type: command
              command: ".claude/scripts/worktree-create.sh"
              timeout: 120
    files:
      - /path/to/rules/orchestrator/dispatch.md
    scripts:
      - /path/to/rules/orchestrator/bin/worktree-create.sh
    subagents:
      # Backend — reads acme-api's CLAUDE.md and hooks
      - name: backend_engineer
        profile: backend-engineer
        cwd: acme-api
        append: true
      # Frontend — reads acme-web's CLAUDE.md, rules, and hooks
      - name: frontend_engineer
        profile: frontend-engineer
        cwd: acme-web
        append: true
      # Comms — pure ruly profile, no repo to append
      - name: comms
        profile: comms`,
    annotations: [
      { line: 1, text: "This is the input — one YAML file generates everything above" },
      { line: 19, text: "append: true triggers reading repo's CLAUDE.md, rules, and hooks" },
    ],
  },
};
