import DemoSection from "@/components/DemoSection";

export default function Home() {
  return (
    <main className="min-h-screen bg-gray-950 text-white">
      {/* Hero */}
      <section className="mx-auto max-w-4xl px-4 pt-24 pb-16 text-center">
        <h1 className="text-4xl font-bold tracking-tight sm:text-5xl lg:text-6xl">
          Bring your own rules, skills, and agents to anywhere Claude is installed.
        </h1>
        <p className="mt-6 text-lg text-gray-400 sm:text-xl">
          Three modes: override everything with your stack, merge permanently into theirs, or slip in through gitignored files — invisible to their codebase.
        </p>
        <div className="mt-8 flex justify-center gap-4">
          <a
            href="#demo"
            className="rounded-lg bg-white px-6 py-3 font-semibold text-gray-950 hover:bg-gray-200 transition"
          >
            Try the demo
          </a>
          <a
            href="https://github.com/patrickclery/ruly"
            className="rounded-lg border border-gray-700 px-6 py-3 font-semibold text-gray-300 hover:border-gray-500 hover:text-white transition"
          >
            GitHub
          </a>
        </div>
      </section>

      {/* Interactive Demo */}
      <DemoSection />

      {/* Feature highlights */}
      <section className="mx-auto max-w-4xl px-4 py-16">
        <div className="grid grid-cols-1 gap-6 md:grid-cols-3">
          <div className="rounded-lg border border-gray-800 bg-gray-900 p-6">
            <h3 className="text-lg font-semibold text-white">Profiles</h3>
            <p className="mt-2 text-sm text-gray-400">
              Define task-specific profiles that load only the rules you need. One YAML file controls everything.
            </p>
          </div>
          <div className="rounded-lg border border-gray-800 bg-gray-900 p-6">
            <h3 className="text-lg font-semibold text-white">Subagents</h3>
            <p className="mt-2 text-sm text-gray-400">
              Dispatch specialized agents into repos. Each inherits its repo&apos;s CLAUDE.md, rules, and hooks automatically.
            </p>
          </div>
          <div className="rounded-lg border border-gray-800 bg-gray-900 p-6">
            <h3 className="text-lg font-semibold text-white">Three Modes</h3>
            <p className="mt-2 text-sm text-gray-400">
              Override, merge, or ghost. Deploy your full stack without touching their codebase.
            </p>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="border-t border-gray-800 py-8">
        <div className="mx-auto max-w-4xl px-4 flex flex-col items-center gap-4 sm:flex-row sm:justify-between">
          <div className="text-sm text-gray-500">
            <span className="font-mono">gem install ruly</span>
          </div>
          <div className="flex gap-6 text-sm text-gray-500">
            <a href="https://github.com/patrickclery/ruly" className="hover:text-white transition">
              GitHub
            </a>
            <a href="https://rubygems.org/gems/ruly" className="hover:text-white transition">
              RubyGems
            </a>
          </div>
        </div>
      </footer>
    </main>
  );
}
