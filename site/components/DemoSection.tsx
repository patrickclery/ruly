"use client";

import { useState, useCallback } from "react";
import Terminal from "./Terminal";
import FilePreview from "./FilePreview";
import { FILES } from "@/lib/demo-data";

export default function DemoSection() {
  const [selectedFile, setSelectedFile] = useState<string | null>(null);

  const handleFileSelect = useCallback((fileKey: string) => {
    setSelectedFile(fileKey);
  }, []);

  const handleClosePreview = useCallback(() => {
    setSelectedFile(null);
  }, []);

  return (
    <section id="demo" className="mx-auto max-w-4xl px-4 py-16">
      <Terminal onFileSelect={handleFileSelect} />

      {/* File Preview Modal */}
      <FilePreview
        file={selectedFile ? FILES[selectedFile] : null}
        onClose={handleClosePreview}
      />
    </section>
  );
}
