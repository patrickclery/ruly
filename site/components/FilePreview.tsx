"use client";

import { Prism as SyntaxHighlighter } from "react-syntax-highlighter";
import { vscDarkPlus } from "react-syntax-highlighter/dist/esm/styles/prism";
import { DemoFile } from "@/lib/demo-types";

interface FilePreviewProps {
  file: DemoFile | null;
}

export default function FilePreview({ file }: FilePreviewProps) {
  if (!file) {
    return (
      <div className="flex h-full items-center justify-center text-gray-500">
        Select a file to preview
      </div>
    );
  }

  return (
    <div className="flex h-full flex-col">
      {/* Header */}
      <div className="border-b border-gray-700 px-4 py-2 font-mono text-sm text-gray-300">
        {file.path}
      </div>

      {/* Content */}
      <div className="flex-1 overflow-y-auto p-1">
        <SyntaxHighlighter
          language={file.language}
          style={vscDarkPlus}
          showLineNumbers
          customStyle={{
            margin: 0,
            background: "transparent",
            fontSize: "0.8rem",
          }}
        >
          {file.content}
        </SyntaxHighlighter>
      </div>
    </div>
  );
}
