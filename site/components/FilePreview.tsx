"use client";

import { Prism as SyntaxHighlighter } from "react-syntax-highlighter";
import { vscDarkPlus } from "react-syntax-highlighter/dist/esm/styles/prism";
import { DemoFile } from "@/lib/demo-data";

interface FilePreviewProps {
  file: DemoFile | null;
  onClose: () => void;
}

export default function FilePreview({ file, onClose }: FilePreviewProps) {
  if (!file) return null;

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-sm"
      onClick={onClose}
    >
      <div
        className="mx-4 w-full max-w-3xl rounded-lg border border-gray-700 bg-bg-secondary shadow-2xl"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div className="flex items-center justify-between border-b border-gray-700 px-5 py-3">
          <span className="font-mono text-sm text-gray-300">{file.path}</span>
          <button
            onClick={onClose}
            className="cursor-pointer text-gray-400 hover:text-white transition duration-150 text-lg leading-none"
          >
            &#x2715;
          </button>
        </div>

        {/* Content with annotations */}
        <div className="max-h-[70vh] overflow-y-auto relative p-1">
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

          {/* Annotation overlays */}
          {file.annotations.map((annotation, i) => (
            <div
              key={i}
              className="absolute right-5 flex items-center gap-2"
              style={{ top: `${(annotation.line - 1) * 1.5 + 0.75}rem` }}
            >
              <div className="h-px w-8 bg-yellow-500/50" />
              <span className="whitespace-nowrap rounded-md bg-yellow-500/20 px-3 py-1 text-xs font-medium text-yellow-400 border border-yellow-500/30">
                &larr; {annotation.text}
              </span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
