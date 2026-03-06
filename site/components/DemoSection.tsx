"use client";

import { useState, useCallback } from "react";
import Terminal from "./Terminal";
import FileTree from "./FileTree";
import FilePreview from "./FilePreview";
import { FILES } from "@/lib/demo-data";
import { FILE_TREE } from "@/lib/tree-data";

export default function DemoSection() {
  const [treeVisible, setTreeVisible] = useState(false);
  const [selectedFile, setSelectedFile] = useState<string | null>(null);

  const handleSquashComplete = useCallback(() => {
    setTreeVisible(true);
  }, []);

  const handleFileSelect = useCallback((fileKey: string) => {
    setSelectedFile(fileKey);
  }, []);

  const handleClosePreview = useCallback(() => {
    setSelectedFile(null);
  }, []);

  return (
    <section id="demo" className="mx-auto max-w-6xl px-4 py-16">
      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        {/* Left: Terminal */}
        <Terminal
          onFileSelect={handleFileSelect}
          onSquashComplete={handleSquashComplete}
        />

        {/* Right: File Tree */}
        <FileTree
          tree={FILE_TREE}
          onFileClick={handleFileSelect}
          visible={treeVisible}
        />
      </div>

      {/* File Preview Modal */}
      <FilePreview
        file={selectedFile ? FILES[selectedFile] : null}
        onClose={handleClosePreview}
      />
    </section>
  );
}
