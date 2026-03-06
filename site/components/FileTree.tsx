"use client";

import { useState } from "react";
import { TreeNode } from "@/lib/tree-data";

interface FileTreeProps {
  tree: TreeNode;
  onFileClick: (fileKey: string) => void;
  visible: boolean;
}

function TreeItem({
  node,
  depth,
  onFileClick,
}: {
  node: TreeNode;
  depth: number;
  onFileClick: (fileKey: string) => void;
}) {
  const [expanded, setExpanded] = useState(true);
  const indent = depth * 16;

  if (node.type === "directory") {
    return (
      <div>
        <button
          onClick={() => setExpanded(!expanded)}
          className="flex w-full items-center gap-1 py-0.5 text-left text-gray-300 hover:text-white"
          style={{ paddingLeft: indent }}
        >
          <span className="text-xs">{expanded ? "▼" : "▶"}</span>
          <span className="text-blue-400">📁</span>
          <span>{node.name}</span>
          {node.comment && (
            <span className="ml-2 text-xs text-gray-500">// {node.comment}</span>
          )}
        </button>
        {expanded &&
          node.children?.map((child, i) => (
            <TreeItem key={i} node={child} depth={depth + 1} onFileClick={onFileClick} />
          ))}
      </div>
    );
  }

  return (
    <button
      onClick={() => node.fileKey && onFileClick(node.fileKey)}
      className={`flex w-full items-center gap-1 py-0.5 text-left ${
        node.fileKey
          ? "text-gray-300 hover:text-white cursor-pointer"
          : "text-gray-500 cursor-default"
      }`}
      style={{ paddingLeft: indent }}
      disabled={!node.fileKey}
    >
      <span className="text-xs opacity-0">▶</span>
      <span>📄</span>
      <span>{node.name}</span>
      {node.comment && (
        <span className="ml-2 text-xs text-gray-500">// {node.comment}</span>
      )}
    </button>
  );
}

export default function FileTree({ tree, onFileClick, visible }: FileTreeProps) {
  return (
    <div
      className={`rounded-lg border border-gray-700 bg-gray-900 font-mono text-xs transition-all duration-500 ${
        visible ? "opacity-100 translate-x-0" : "opacity-0 translate-x-4"
      }`}
    >
      <div className="border-b border-gray-700 px-4 py-2 text-xs text-gray-400">
        EXPLORER
      </div>
      <div className="h-[400px] overflow-y-auto p-2">
        <TreeItem node={tree} depth={0} onFileClick={onFileClick} />
      </div>
    </div>
  );
}
