"use client";

import { useEffect, useRef, useState, useCallback } from "react";
import Typed from "typed.js";
import { SQUASH_COMMAND, SQUASH_OUTPUT, MENU_OPTIONS } from "@/lib/demo-data";

interface TerminalProps {
  onFileSelect: (fileKey: string) => void;
  onSquashComplete: () => void;
}

type Phase = "idle" | "typing-command" | "showing-output" | "menu";

function colorForLine(line: string): string {
  if (line.startsWith("Squashing") || line.startsWith("Done.") || line.startsWith("  Done.")) {
    return "text-green-400";
  }
  if (line.includes("Subagent:")) {
    return "text-cyan-400";
  }
  if (line.includes("Appending:") || line.includes("Merging:")) {
    return "text-gray-400";
  }
  if (line.includes("Writing:") || line.includes("Copying:")) {
    return "text-emerald-300";
  }
  if (line.includes("Reading:")) {
    return "text-gray-500";
  }
  return "text-gray-300";
}

export default function Terminal({ onFileSelect, onSquashComplete }: TerminalProps) {
  const typedRef = useRef<HTMLSpanElement>(null);
  const terminalRef = useRef<HTMLDivElement>(null);
  const [phase, setPhase] = useState<Phase>("idle");
  const [output, setOutput] = useState<string[]>([]);
  const [showMenu, setShowMenu] = useState(false);

  // Phase 1: Type the command
  useEffect(() => {
    if (!typedRef.current) return;

    const typed = new Typed(typedRef.current, {
      strings: [SQUASH_COMMAND],
      typeSpeed: 50,
      showCursor: true,
      cursorChar: "\u2588",
      onComplete: () => {
        setPhase("showing-output");
      },
    });

    setPhase("typing-command");
    return () => typed.destroy();
  }, []);

  // Phase 2: Animate output lines
  useEffect(() => {
    if (phase !== "showing-output") return;

    const lines = SQUASH_OUTPUT.split("\n");
    let i = 0;
    const interval = setInterval(() => {
      if (i < lines.length) {
        setOutput((prev) => [...prev, lines[i]]);
        i++;
      } else {
        clearInterval(interval);
        onSquashComplete();
        setShowMenu(true);
        setPhase("menu");
      }
    }, 80);

    return () => clearInterval(interval);
  }, [phase, onSquashComplete]);

  // Phase 3: Listen for key presses
  const handleKeyPress = useCallback(
    (e: KeyboardEvent) => {
      if (phase !== "menu") return;
      const option = MENU_OPTIONS.find((o) => o.key === e.key);
      if (option) {
        onFileSelect(option.fileKey);
      }
    },
    [phase, onFileSelect]
  );

  useEffect(() => {
    window.addEventListener("keydown", handleKeyPress);
    return () => window.removeEventListener("keydown", handleKeyPress);
  }, [handleKeyPress]);

  // Auto-scroll terminal
  useEffect(() => {
    if (terminalRef.current) {
      terminalRef.current.scrollTop = terminalRef.current.scrollHeight;
    }
  }, [output, showMenu]);

  return (
    <div className="terminal-glow rounded-lg border border-gray-700 bg-gray-950 font-mono text-sm shadow-2xl">
      {/* Title bar */}
      <div className="flex items-center gap-2 border-b border-gray-700 px-4 py-2">
        <div className="h-3 w-3 rounded-full bg-red-500 cursor-pointer hover:brightness-110 transition duration-150" />
        <div className="h-3 w-3 rounded-full bg-yellow-500 cursor-pointer hover:brightness-110 transition duration-150" />
        <div className="h-3 w-3 rounded-full bg-green-500 cursor-pointer hover:brightness-110 transition duration-150" />
        <span className="ml-2 text-xs text-gray-400">~/agents/orchestrator</span>
      </div>

      {/* Terminal body */}
      <div ref={terminalRef} className="h-[400px] overflow-y-auto p-4">
        {/* Command line */}
        <div className="text-green-400">
          <span className="text-gray-500">$ </span>
          <span ref={typedRef} />
        </div>

        {/* Output lines */}
        {output.map((line, i) => (
          <div key={i} className={colorForLine(line)}>
            {line}
          </div>
        ))}

        {/* Menu */}
        {showMenu && (
          <div className="mt-4">
            <div className="text-yellow-400">Explore the output:</div>
            {MENU_OPTIONS.map((opt) => (
              <button
                key={opt.key}
                onClick={() => onFileSelect(opt.fileKey)}
                className="cursor-pointer block text-left text-cyan-400 hover:text-cyan-300 transition duration-150"
              >
                <span className="text-yellow-400">[{opt.key}]</span> {opt.label}
              </button>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
