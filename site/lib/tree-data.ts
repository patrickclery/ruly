export interface TreeNode {
  name: string;
  type: "file" | "directory";
  fileKey?: string;
  comment?: string;
  children?: TreeNode[];
}

export const FILE_TREE: TreeNode = {
  name: "~/agents/orchestrator",
  type: "directory",
  children: [
    {
      name: "CLAUDE.local.md",
      type: "file",
      fileKey: "claude-local",
      comment: "Generated orchestrator rules",
    },
    {
      name: ".mcp.json",
      type: "file",
      fileKey: "mcp-json",
      comment: "MCP servers (collected from all subagents)",
    },
    {
      name: ".claude",
      type: "directory",
      children: [
        {
          name: "agents",
          type: "directory",
          children: [
            {
              name: "backend_engineer.md",
              type: "file",
              fileKey: "backend-agent",
              comment: "Has acme-api's CLAUDE.md + hooks baked in",
            },
            {
              name: "frontend_engineer.md",
              type: "file",
              fileKey: "frontend-agent",
              comment: "Has acme-web's CLAUDE.md + rules + hooks baked in",
            },
            {
              name: "comms.md",
              type: "file",
              comment: "Pure ruly profile (no repo append)",
            },
          ],
        },
        {
          name: "scripts",
          type: "directory",
          children: [
            {
              name: "worktree-create.sh",
              type: "file",
              comment: "Propagated to all submodule dirs",
            },
          ],
        },
        {
          name: "settings.local.json",
          type: "file",
          comment: "Parent hooks (WorktreeCreate)",
        },
      ],
    },
    {
      name: "acme-api",
      type: "directory",
      comment: "Backend repo (git submodule)",
      children: [
        { name: "CLAUDE.md", type: "file", comment: "1800-line repo-specific guidance" },
        {
          name: ".claude",
          type: "directory",
          children: [
            { name: "settings.json", type: "file", comment: "No custom hooks" },
          ],
        },
      ],
    },
    {
      name: "acme-web",
      type: "directory",
      comment: "Frontend repo (git submodule)",
      children: [
        { name: "CLAUDE.md", type: "file", comment: "500-line repo-specific guidance" },
        {
          name: ".claude",
          type: "directory",
          children: [
            {
              name: "rules",
              type: "directory",
              children: [
                { name: "command-timeouts.md", type: "file", comment: "Repo-specific rules" },
              ],
            },
            {
              name: "hooks",
              type: "directory",
              children: [
                { name: "eslint-fix.sh", type: "file", comment: "Repo-specific hook script" },
              ],
            },
            {
              name: "settings.json",
              type: "file",
              comment: "PostToolUse hook for ESLint",
            },
          ],
        },
      ],
    },
  ],
};
