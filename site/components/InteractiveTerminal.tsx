"use client";

import { useEffect, useRef, useState, useCallback } from "react";
import type { DemoAnswers, ProjectType, DeployMode } from "@/lib/demo-types";

interface InteractiveTerminalProps {
  onComplete: (answers: DemoAnswers) => void;
}

type Phase = "q-project" | "q-mode" | "q-name" | "q-name2" | "processing";

interface HistoryEntry {
  question: string;
  answer: string;
}

const SPINNER_CHARS = ["|", "/", "-", "\\"];

const CLAUDE_VERBS = [
  "Spelunking!",
  "Investigating!",
  "Researching!",
  "Exploring!",
  "Analyzing!",
  "Thinking!",
];

function isValidKebab(value: string): boolean {
  if (value.length === 0 || value.length > 12) return false;
  if (value.startsWith("-")) return false;
  if (value.includes("--")) return false;
  return /^[a-z0-9-]+$/.test(value);
}

export default function InteractiveTerminal({
  onComplete,
}: InteractiveTerminalProps) {
  const bodyRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  const [phase, setPhase] = useState<Phase>("q-project");
  const [history, setHistory] = useState<HistoryEntry[]>([]);
  const [answers, setAnswers] = useState<Partial<DemoAnswers>>({});
  const [inputValue, setInputValue] = useState("");
  const [spinnerIdx, setSpinnerIdx] = useState(0);
  const [processingVerb] = useState(
    () => CLAUDE_VERBS[Math.floor(Math.random() * CLAUDE_VERBS.length)]
  );

  // Auto-scroll to bottom
  useEffect(() => {
    if (bodyRef.current) {
      bodyRef.current.scrollTop = bodyRef.current.scrollHeight;
    }
  }, [phase, history]);

  // Auto-focus input when entering name phases
  useEffect(() => {
    if ((phase === "q-name" || phase === "q-name2") && inputRef.current) {
      inputRef.current.focus();
    }
  }, [phase]);

  // Spinner animation during processing
  useEffect(() => {
    if (phase !== "processing") return;
    const interval = setInterval(() => {
      setSpinnerIdx((prev) => (prev + 1) % SPINNER_CHARS.length);
    }, 100);
    return () => clearInterval(interval);
  }, [phase]);

  // Call onComplete after 2s of processing
  useEffect(() => {
    if (phase !== "processing") return;
    const timer = setTimeout(() => {
      onComplete(answers as DemoAnswers);
    }, 2000);
    return () => clearTimeout(timer);
  }, [phase, answers, onComplete]);

  const addHistory = useCallback((question: string, answer: string) => {
    setHistory((prev) => [...prev, { question, answer }]);
  }, []);

  const handleProjectType = (type: ProjectType) => {
    addHistory("Which best fits your project?", type === "single" ? "Single repo" : "Multi-repo");
    setAnswers((prev) => ({ ...prev, projectType: type }));
    setPhase("q-mode");
  };

  const handleDeployMode = (mode: DeployMode) => {
    const labels: Record<DeployMode, string> = {
      override: "Override",
      merge: "Merge",
      ghost: "Ghost",
    };
    addHistory("How do you want to deploy your rules?", labels[mode]);
    setAnswers((prev) => ({ ...prev, deployMode: mode }));
    setPhase("q-name");
  };

  const handleNameSubmit = () => {
    const trimmed = inputValue.trim();
    if (!isValidKebab(trimmed)) return;

    if (phase === "q-name") {
      const question =
        answers.projectType === "single"
          ? "What's your repo called?"
          : "Name your first repo:";
      addHistory(question, trimmed);
      setAnswers((prev) => ({ ...prev, repoName: trimmed }));
      setInputValue("");
      if (answers.projectType === "multi") {
        setPhase("q-name2");
      } else {
        setPhase("processing");
      }
    } else if (phase === "q-name2") {
      addHistory("Name your second repo:", trimmed);
      setAnswers((prev) => ({ ...prev, repoName2: trimmed }));
      setInputValue("");
      setPhase("processing");
    }
  };

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const val = e.target.value.toLowerCase().replace(/[^a-z0-9-]/g, "");
    if (val.length <= 12) {
      setInputValue(val);
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === "Enter") {
      handleNameSubmit();
    }
  };

  return (
    <div className="rounded-lg border border-gray-700 bg-gray-950 font-mono text-sm shadow-2xl">
      {/* Title bar */}
      <div className="flex items-center gap-2 border-b border-gray-700 px-4 py-2">
        <div className="h-3 w-3 rounded-full bg-red-500" />
        <div className="h-3 w-3 rounded-full bg-yellow-500" />
        <div className="h-3 w-3 rounded-full bg-green-500" />
        <span className="ml-2 text-xs text-gray-400">
          ruly interactive setup
        </span>
      </div>

      {/* Terminal body */}
      <div
        ref={bodyRef}
        className="min-h-[300px] max-h-[500px] overflow-y-auto p-6"
      >
        {/* History */}
        {history.map((entry, i) => (
          <div key={i} className="mb-2">
            <div className="text-gray-400">{entry.question}</div>
            <div className="text-green-400">
              <span className="mr-1">&#9658;</span>
              {entry.answer}
            </div>
          </div>
        ))}

        {/* Current question */}
        {phase === "q-project" && (
          <div>
            <div className="mb-3 text-gray-400">
              Which best fits your project?
            </div>
            <div className="flex gap-3">
              <button
                onClick={() => handleProjectType("single")}
                className="cursor-pointer rounded border border-gray-600 px-4 py-2 text-gray-300 transition duration-150 hover:border-green-500 hover:text-green-400"
              >
                Single repo
              </button>
              <button
                onClick={() => handleProjectType("multi")}
                className="cursor-pointer rounded border border-gray-600 px-4 py-2 text-gray-300 transition duration-150 hover:border-green-500 hover:text-green-400"
              >
                Multi-repo
              </button>
            </div>
          </div>
        )}

        {phase === "q-mode" && (
          <div>
            <div className="mb-3 text-gray-400">
              How do you want to deploy your rules?
            </div>
            <div className="flex flex-wrap gap-3">
              <button
                onClick={() => handleDeployMode("override")}
                className="cursor-pointer rounded border border-gray-600 px-4 py-2 text-left text-gray-300 transition duration-150 hover:border-green-500 hover:text-green-400"
              >
                <span className="font-bold">Override</span>
                <span className="ml-1 text-xs text-gray-500">
                  — replace theirs
                </span>
              </button>
              <button
                onClick={() => handleDeployMode("merge")}
                className="cursor-pointer rounded border border-gray-600 px-4 py-2 text-left text-gray-300 transition duration-150 hover:border-green-500 hover:text-green-400"
              >
                <span className="font-bold">Merge</span>
                <span className="ml-1 text-xs text-gray-500">
                  — layer on top
                </span>
              </button>
              <button
                onClick={() => handleDeployMode("ghost")}
                className="cursor-pointer rounded border border-gray-600 px-4 py-2 text-left text-gray-300 transition duration-150 hover:border-green-500 hover:text-green-400"
              >
                <span className="font-bold">Ghost</span>
                <span className="ml-1 text-xs text-gray-500">
                  — merge + gitignored
                </span>
              </button>
            </div>
          </div>
        )}

        {phase === "q-name" && (
          <div>
            <div className="mb-3 text-gray-400">
              {answers.projectType === "single"
                ? "What's your repo called?"
                : "Name your first repo:"}
            </div>
            <div className="flex items-center gap-2">
              <input
                ref={inputRef}
                type="text"
                value={inputValue}
                onChange={handleInputChange}
                onKeyDown={handleKeyDown}
                placeholder="my-app"
                className="border-b border-gray-600 bg-transparent text-green-400 outline-none transition duration-150 focus:border-green-500"
              />
              <button
                onClick={handleNameSubmit}
                disabled={!isValidKebab(inputValue.trim())}
                className="cursor-pointer rounded border border-gray-600 px-3 py-1 text-gray-300 transition duration-150 hover:border-green-500 hover:text-green-400 disabled:cursor-default disabled:opacity-40 disabled:hover:border-gray-600 disabled:hover:text-gray-300"
              >
                Enter &#8629;
              </button>
            </div>
          </div>
        )}

        {phase === "q-name2" && (
          <div>
            <div className="mb-3 text-gray-400">Name your second repo:</div>
            <div className="flex items-center gap-2">
              <input
                ref={inputRef}
                type="text"
                value={inputValue}
                onChange={handleInputChange}
                onKeyDown={handleKeyDown}
                placeholder="my-app"
                className="border-b border-gray-600 bg-transparent text-green-400 outline-none transition duration-150 focus:border-green-500"
              />
              <button
                onClick={handleNameSubmit}
                disabled={!isValidKebab(inputValue.trim())}
                className="cursor-pointer rounded border border-gray-600 px-3 py-1 text-gray-300 transition duration-150 hover:border-green-500 hover:text-green-400 disabled:cursor-default disabled:opacity-40 disabled:hover:border-gray-600 disabled:hover:text-gray-300"
              >
                Enter &#8629;
              </button>
            </div>
          </div>
        )}

        {phase === "processing" && (
          <div className="text-yellow-400">
            <span className="mr-2">{SPINNER_CHARS[spinnerIdx]}</span>
            {processingVerb}
          </div>
        )}
      </div>
    </div>
  );
}
