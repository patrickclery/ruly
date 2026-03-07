"use client";

import { useState } from "react";
import { TreeNode } from "@/lib/demo-types";

interface FileTreeProps {
  tree: TreeNode;
  onFileClick: (fileKey: string) => void;
  selectedFileKey: string | null;
}

function TreeItem({
  node,
  depth,
  onFileClick,
  selectedFileKey,
}: {
  node: TreeNode;
  depth: number;
  onFileClick: (fileKey: string) => void;
  selectedFileKey: string | null;
}) {
  const [expanded, setExpanded] = useState(true);
  const indent = depth * 16;

  if (node.type === "directory") {
    return (
      <div>
        <button
          onClick={() => setExpanded(!expanded)}
          className={`cursor-pointer flex w-full items-center gap-1 py-0.5 text-left text-gray-300 hover:text-white transition duration-150 ${
            node.dimmed ? "opacity-50 italic" : ""
          }`}
          style={{ paddingLeft: indent }}
        >
          <span className="text-xs text-gray-500">{expanded ? "\u25BC" : "\u25B6"}</span>
          <span>{node.name}</span>
          {node.comment && (
            <span className="ml-2 shrink-0 text-xs italic text-gray-600 hidden lg:inline">// {node.comment}</span>
          )}
        </button>
        {expanded &&
          node.children?.map((child, i) => (
            <TreeItem
              key={i}
              node={child}
              depth={depth + 1}
              onFileClick={onFileClick}
              selectedFileKey={selectedFileKey}
            />
          ))}
      </div>
    );
  }

  const isSelected = node.fileKey != null && node.fileKey === selectedFileKey;

  return (
    <button
      onClick={() => node.fileKey && onFileClick(node.fileKey)}
      className={`flex w-full items-center gap-1 py-0.5 text-left transition duration-150 ${
        node.dimmed ? "opacity-50 italic" : ""
      } ${
        isSelected
          ? "bg-gray-800 text-white"
          : node.fileKey
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
        <span className="ml-2 shrink-0 text-xs text-gray-500 hidden lg:inline">// {node.comment}</span>
      )}
    </button>
  );
}

export default function FileTree({ tree, onFileClick, selectedFileKey }: FileTreeProps) {
  return (
    <TreeItem node={tree} depth={0} onFileClick={onFileClick} selectedFileKey={selectedFileKey} />
  );
}
