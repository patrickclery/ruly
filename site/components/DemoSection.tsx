"use client";

import { useState, useCallback } from "react";
import InteractiveTerminal from "./InteractiveTerminal";
import Explorer from "./Explorer";
import type { DemoAnswers, DemoData } from "@/lib/demo-types";
import { generateDemoData } from "@/lib/generate-demo-data";

type DemoPhase = "terminal" | "transitioning" | "explorer";

export default function DemoSection() {
  const [phase, setPhase] = useState<DemoPhase>("terminal");
  const [demoData, setDemoData] = useState<DemoData | null>(null);

  const handleComplete = useCallback((answers: DemoAnswers) => {
    const data = generateDemoData(answers);
    setDemoData(data);
    setPhase("transitioning");
    setTimeout(() => setPhase("explorer"), 350);
  }, []);

  return (
    <section id="demo" className="mx-auto max-w-5xl px-4 py-16">
      {phase === "terminal" && (
        <div className="demo-phase-enter">
          <InteractiveTerminal onComplete={handleComplete} />
        </div>
      )}

      {phase === "transitioning" && (
        <div className="demo-phase-exit">
          <InteractiveTerminal onComplete={() => {}} />
        </div>
      )}

      {phase === "explorer" && demoData && (
        <div className="demo-phase-enter">
          <Explorer data={demoData} />
        </div>
      )}
    </section>
  );
}
