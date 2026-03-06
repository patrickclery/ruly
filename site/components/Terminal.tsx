"use client";

import { useEffect, useRef, useState, useCallback } from "react";
import Typed from "typed.js";
import {
  PWD_OUTPUT,
  LS_OUTPUT,
  SQUASH_COMMAND,
  SQUASH_OUTPUT,
  TREE_OUTPUT,
  MENU_OPTIONS,
} from "@/lib/demo-data";

interface TerminalProps {
  onFileSelect: (fileKey: string) => void;
}

type Phase =
  | "typing-pwd"
  | "showing-pwd"
  | "typing-ls"
  | "showing-ls"
  | "typing-squash"
  | "showing-squash"
  | "typing-tree"
  | "showing-tree"
  | "menu";

interface TerminalLine {
  type: "prompt" | "plain" | "ls" | "squash" | "tree";
  text?: string;
  command?: string;
  color?: string;
  suffix?: string;
  suffixColor?: string;
}

function squashColor(line: string): string {
  if (line.startsWith("Squashing") || line.startsWith("Done.") || line.startsWith("  Done.")) {
    return "text-green-400";
  }
  if (line.includes("Subagent:")) return "text-cyan-400";
  if (line.includes("Appending:") || line.includes("Merging:")) return "text-gray-400";
  if (line.includes("Writing:") || line.includes("Copying:")) return "text-emerald-300";
  if (line.includes("Reading:")) return "text-gray-500";
  return "text-gray-300";
}

function treeColor(line: string): string {
  if (line.includes("#")) {
    // Split at the comment — tree structure is one color, comment is another
    return "text-gray-300";
  }
  if (line.includes("/")) return "text-blue-400";
  return "text-gray-300";
}

export default function Terminal({ onFileSelect }: TerminalProps) {
  const typedRef = useRef<HTMLSpanElement>(null);
  const terminalRef = useRef<HTMLDivElement>(null);
  const [phase, setPhase] = useState<Phase>("typing-pwd");
  const [lines, setLines] = useState<TerminalLine[]>([]);
  const [showMenu, setShowMenu] = useState(false);
  const [activeCommand, setActiveCommand] = useState<string | null>(null);

  const addLine = useCallback((line: TerminalLine) => {
    setLines((prev) => [...prev, line]);
  }, []);

  const addPrompt = useCallback((command: string) => {
    setLines((prev) => [...prev, { type: "prompt", command }]);
  }, []);

  // Typed.js for the current command
  useEffect(() => {
    if (!typedRef.current || !activeCommand) return;

    const typed = new Typed(typedRef.current, {
      strings: [activeCommand],
      typeSpeed: 40,
      showCursor: true,
      cursorChar: "\u2588",
      onComplete: () => {
        if (phase === "typing-pwd") {
          setActiveCommand(null);
          setPhase("showing-pwd");
        } else if (phase === "typing-ls") {
          setActiveCommand(null);
          setPhase("showing-ls");
        } else if (phase === "typing-squash") {
          setActiveCommand(null);
          setPhase("showing-squash");
        } else if (phase === "typing-tree") {
          setActiveCommand(null);
          setPhase("showing-tree");
        }
      },
    });

    return () => typed.destroy();
  }, [activeCommand, phase]);

  // Phase: typing-pwd
  useEffect(() => {
    if (phase === "typing-pwd") setActiveCommand("pwd");
  }, [phase]);

  // Phase: showing-pwd
  useEffect(() => {
    if (phase !== "showing-pwd") return;
    addPrompt("pwd");
    addLine({ type: "plain", text: PWD_OUTPUT, color: "text-gray-300" });
    const timer = setTimeout(() => setPhase("typing-ls"), 400);
    return () => clearTimeout(timer);
  }, [phase, addLine, addPrompt]);

  // Phase: typing-ls
  useEffect(() => {
    if (phase === "typing-ls") setActiveCommand("ls -la");
  }, [phase]);

  // Phase: showing-ls
  useEffect(() => {
    if (phase !== "showing-ls") return;
    addPrompt("ls -la");
    let i = 0;
    const interval = setInterval(() => {
      if (i < LS_OUTPUT.length) {
        const entry = LS_OUTPUT[i];
        addLine({
          type: "ls",
          text: entry.text,
          color: entry.color,
          suffix: entry.suffix,
          suffixColor: entry.suffixColor,
        });
        i++;
      } else {
        clearInterval(interval);
        setTimeout(() => setPhase("typing-squash"), 600);
      }
    }, 60);
    return () => clearInterval(interval);
  }, [phase, addLine, addPrompt]);

  // Phase: typing-squash
  useEffect(() => {
    if (phase === "typing-squash") setActiveCommand(SQUASH_COMMAND);
  }, [phase]);

  // Phase: showing-squash
  useEffect(() => {
    if (phase !== "showing-squash") return;
    addPrompt(SQUASH_COMMAND);
    const squashLines = SQUASH_OUTPUT.split("\n");
    let i = 0;
    const interval = setInterval(() => {
      if (i < squashLines.length) {
        const currentLine = squashLines[i];
        addLine({ type: "squash", text: currentLine });
        i++;
      } else {
        clearInterval(interval);
        setTimeout(() => setPhase("typing-tree"), 600);
      }
    }, 80);
    return () => clearInterval(interval);
  }, [phase, addLine, addPrompt]);

  // Phase: typing-tree
  useEffect(() => {
    if (phase === "typing-tree") setActiveCommand("tree");
  }, [phase]);

  // Phase: showing-tree
  useEffect(() => {
    if (phase !== "showing-tree") return;
    addPrompt("tree");
    const treeLines = TREE_OUTPUT.split("\n");
    let i = 0;
    const interval = setInterval(() => {
      if (i < treeLines.length) {
        const currentLine = treeLines[i];
        addLine({ type: "tree", text: currentLine });
        i++;
      } else {
        clearInterval(interval);
        setShowMenu(true);
        setPhase("menu");
      }
    }, 40);
    return () => clearInterval(interval);
  }, [phase, addLine, addPrompt]);

  // Listen for key presses in menu phase
  const handleKeyPress = useCallback(
    (e: KeyboardEvent) => {
      if (phase !== "menu") return;
      const option = MENU_OPTIONS.find((o) => o.key === e.key);
      if (option) onFileSelect(option.fileKey);
    },
    [phase, onFileSelect]
  );

  useEffect(() => {
    window.addEventListener("keydown", handleKeyPress);
    return () => window.removeEventListener("keydown", handleKeyPress);
  }, [handleKeyPress]);

  // Auto-scroll
  useEffect(() => {
    if (terminalRef.current) {
      terminalRef.current.scrollTop = terminalRef.current.scrollHeight;
    }
  }, [lines, showMenu, activeCommand]);

  return (
    <div className="terminal-glow rounded-lg border border-gray-700 bg-gray-950 font-mono text-sm shadow-2xl">
      {/* Title bar */}
      <div className="flex items-center gap-2 border-b border-gray-700 px-4 py-2">
        <div className="h-3 w-3 rounded-full bg-red-500" />
        <div className="h-3 w-3 rounded-full bg-yellow-500" />
        <div className="h-3 w-3 rounded-full bg-green-500" />
        <span className="ml-2 text-xs text-gray-400">~/agents/orchestrator</span>
      </div>

      {/* Terminal body */}
      <div ref={terminalRef} className="h-[600px] overflow-y-auto p-4">
        {/* History lines */}
        {lines.map((line, i) => {
          if (line.type === "prompt") {
            return (
              <div key={i} className="text-green-400">
                <span className="text-gray-500">$ </span>
                {line.command}
              </div>
            );
          }
          if (line.type === "ls") {
            return (
              <div key={i}>
                <span className={line.color}>{line.text}</span>
                {line.suffix && (
                  <span className={line.suffixColor}>{line.suffix}</span>
                )}
              </div>
            );
          }
          if (line.type === "squash") {
            return (
              <div key={i} className={squashColor(line.text || "")}>
                {line.text}
              </div>
            );
          }
          if (line.type === "tree") {
            const text = line.text || "";
            const commentIdx = text.indexOf("#");
            if (commentIdx > -1) {
              const structure = text.slice(0, commentIdx);
              const comment = text.slice(commentIdx);
              return (
                <div key={i}>
                  <span className={treeColor(structure)}>{structure}</span>
                  <span className="text-gray-600">{comment}</span>
                </div>
              );
            }
            return (
              <div key={i} className={treeColor(text)}>
                {text}
              </div>
            );
          }
          return (
            <div key={i} className={line.color || "text-gray-300"}>
              {line.text}
            </div>
          );
        })}

        {/* Active typing line */}
        {activeCommand !== null && (
          <div className="text-green-400">
            <span className="text-gray-500">$ </span>
            <span ref={typedRef} />
          </div>
        )}

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
