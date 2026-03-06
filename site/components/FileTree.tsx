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
          className="cursor-pointer flex w-full items-center gap-1 py-0.5 text-left text-gray-300 hover:text-white transition duration-150"
          style={{ paddingLeft: indent }}
        >
          <span className="text-xs text-gray-500">{expanded ? "\u25BC" : "\u25B6"}</span>
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
      className={`flex w-full items-center gap-1 py-0.5 text-left transition duration-150 ${
        node.fileKey
          ? "text-gray-300 hover:text-white cursor-pointer"
          : "text-gray-500 cursor-default"
      }`}
      style={{ paddingLeft: indent }}
      disabled={!node.fileKey}
    >
      <span className="text-xs opacity-0">{"\u25B6"}</span>
      <span className="text-gray-600">&middot;</span>
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
      className={`rounded-lg border border-gray-700 bg-bg-secondary font-mono text-xs transition-all duration-500 ${
        visible ? "opacity-100 translate-x-0" : "opacity-0 translate-x-4"
      }`}
    >
      <div className="border-b border-gray-700 px-4 py-2 text-xs text-gray-400">
        EXPLORER
      </div>
      <div className="h-[600px] overflow-y-auto p-2">
        <TreeItem node={tree} depth={0} onFileClick={onFileClick} />
      </div>
    </div>
  );
}
