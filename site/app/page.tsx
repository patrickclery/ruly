import DemoSection from "@/components/DemoSection";

export default function Home() {
  return (
    <main className="min-h-screen bg-bg-primary text-slate-50">
      {/* Hero */}
      <section className="hero-gradient mx-auto max-w-4xl px-4 pt-24 pb-16 text-center">
        <div className="mb-4 inline-block rounded-full border border-green-500/30 bg-green-500/10 px-4 py-1 text-sm font-medium text-green-400">
          gem install ruly
        </div>
        <h1 className="text-4xl font-bold tracking-tight sm:text-5xl lg:text-6xl">
          Bring your own rules, skills, and agents to anywhere Claude is installed.
        </h1>
        <p className="mt-6 text-lg text-gray-400 sm:text-xl">
          Three modes: override everything with your stack, merge permanently into theirs, or slip in through gitignored files — invisible to their codebase.
        </p>
        <div className="mt-8 flex justify-center gap-4">
          <a
            href="#demo"
            className="cursor-pointer rounded-lg bg-accent px-6 py-3 font-semibold text-bg-primary hover:brightness-110 transition duration-200"
          >
            Try the demo
          </a>
          <a
            href="https://github.com/patrickclery/ruly"
            className="cursor-pointer rounded-lg border border-gray-700 px-6 py-3 font-semibold text-gray-300 hover:border-gray-500 hover:text-white transition duration-200"
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
          <div className="card-glow rounded-lg border border-gray-800 bg-bg-secondary p-6 transition duration-200">
            <svg className="h-8 w-8 text-green-500 mb-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M6.429 9.75L2.25 12l4.179 2.25m0-4.5l5.571 3 5.571-3m-11.142 0L2.25 7.5 12 2.25l9.75 5.25-9.75 5.25m0 0v6.75m5.571-8.25l4.179 2.25m0 0L12 20.25 2.25 14.25" />
            </svg>
            <h3 className="text-lg font-semibold text-white">Profiles</h3>
            <p className="mt-2 text-sm text-gray-400">
              Define task-specific profiles that load only the rules you need. One YAML file controls everything.
            </p>
          </div>
          <div className="card-glow rounded-lg border border-gray-800 bg-bg-secondary p-6 transition duration-200">
            <svg className="h-8 w-8 text-green-500 mb-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M18 18.72a9.094 9.094 0 003.741-.479 3 3 0 00-4.682-2.72m.94 3.198l.001.031c0 .225-.012.447-.037.666A11.944 11.944 0 0112 21c-2.17 0-4.207-.576-5.963-1.584A6.062 6.062 0 016 18.719m12 0a5.971 5.971 0 00-.941-3.197m0 0A5.995 5.995 0 0012 12.75a5.995 5.995 0 00-5.058 2.772m0 0a3 3 0 00-4.681 2.72 8.986 8.986 0 003.74.477m.94-3.197a5.971 5.971 0 00-.94 3.197M15 6.75a3 3 0 11-6 0 3 3 0 016 0zm6 3a2.25 2.25 0 11-4.5 0 2.25 2.25 0 014.5 0zm-13.5 0a2.25 2.25 0 11-4.5 0 2.25 2.25 0 014.5 0z" />
            </svg>
            <h3 className="text-lg font-semibold text-white">Subagents</h3>
            <p className="mt-2 text-sm text-gray-400">
              Dispatch specialized agents into repos. Each inherits its repo&apos;s CLAUDE.md, rules, and hooks automatically.
            </p>
          </div>
          <div className="card-glow rounded-lg border border-gray-800 bg-bg-secondary p-6 transition duration-200">
            <svg className="h-8 w-8 text-green-500 mb-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z" />
            </svg>
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
            <a href="https://github.com/patrickclery/ruly" className="cursor-pointer hover:text-white transition duration-200">
              GitHub
            </a>
            <a href="https://rubygems.org/gems/ruly" className="cursor-pointer hover:text-white transition duration-200">
              RubyGems
            </a>
          </div>
        </div>
      </footer>
    </main>
  );
}
