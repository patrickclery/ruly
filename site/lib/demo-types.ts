export type ProjectType = "single" | "multi";
export type DeployMode = "override" | "merge" | "ghost";

export interface DemoAnswers {
  projectType: ProjectType;
  deployMode: DeployMode;
  repoName: string;
  repoName2?: string;
}

export interface TreeNode {
  name: string;
  type: "file" | "directory";
  fileKey?: string;
  comment?: string;
  dimmed?: boolean;
  children?: TreeNode[];
}

export interface DemoFile {
  path: string;
  content: string;
  language: "markdown" | "yaml" | "json" | "bash";
}

export interface DemoData {
  tree: TreeNode;
  files: Record<string, DemoFile>;
  initialFileKey: string;
}
