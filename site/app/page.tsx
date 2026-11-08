import DemoSection from "@/components/DemoSection";

export default function Home() {
  return (
    <main className="min-h-screen bg-bg-primary text-slate-50">
      {/* Hero */}
      <section className="hero-gradient mx-auto max-w-4xl px-4 pt-24 pb-16 text-center">
        <a
          href="https://github.com/patrickclery/ruly#-quick-install"
          className="mb-4 inline-block cursor-pointer rounded-full border border-green-500/30 bg-green-500/10 px-4 py-1 text-sm font-medium text-green-400 hover:brightness-110 transition duration-200"
        >
          One-line install: ruby setup.rb
        </a>
        <h1 className="text-4xl font-bold tracking-tight sm:text-5xl lg:text-6xl">
          Compose the rules each task needs from one shared rules repo.
        </h1>
        <p className="mt-6 text-lg text-gray-400 sm:text-xl">
          Recipes pick the rules, skills and commands for a task, and requires: pulls in their dependencies. Each subagent gets its own recipe and model, ruly squash --sync shares one rules repo across machines with per-machine overrides:, and every squash that writes files runs checks on the output. The same recipe can also be written as AGENTS.md (-a agents) or packaged as a Claude Code plugin directory (-a claude-plugin).
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
            <h3 className="text-lg font-semibold text-white">Recipes</h3>
            <p className="mt-2 text-sm text-gray-400">
              A named recipe lists the rule files, skills and commands for one task. Dependencies declared with requires: are resolved and included once, and ruly stats lists any circular chains.
            </p>
          </div>
          <div className="card-glow rounded-lg border border-gray-800 bg-bg-secondary p-6 transition duration-200">
            <svg className="h-8 w-8 text-green-500 mb-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M18 18.72a9.094 9.094 0 003.741-.479 3 3 0 00-4.682-2.72m.94 3.198l.001.031c0 .225-.012.447-.037.666A11.944 11.944 0 0112 21c-2.17 0-4.207-.576-5.963-1.584A6.062 6.062 0 016 18.719m12 0a5.971 5.971 0 00-.941-3.197m0 0A5.995 5.995 0 0012 12.75a5.995 5.995 0 00-5.058 2.772m0 0a3 3 0 00-4.681 2.72 8.986 8.986 0 003.74.477m.94-3.197a5.971 5.971 0 00-.94 3.197M15 6.75a3 3 0 11-6 0 3 3 0 016 0zm6 3a2.25 2.25 0 11-4.5 0 2.25 2.25 0 014.5 0zm-13.5 0a2.25 2.25 0 11-4.5 0 2.25 2.25 0 014.5 0z" />
            </svg>
            <h3 className="text-lg font-semibold text-white">Subagents</h3>
            <p className="mt-2 text-sm text-gray-400">
              Each subagent gets its own recipe and model, written to .claude/agents/. The model falls back from the subagent to the recipe to inherit.
            </p>
          </div>
          <div className="card-glow rounded-lg border border-gray-800 bg-bg-secondary p-6 transition duration-200">
            <svg className="h-8 w-8 text-green-500 mb-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75L11.25 15 15 9.75m-3-7.036A11.959 11.959 0 013.598 6 11.99 11.99 0 003 9.749c0 5.592 3.824 10.29 9 11.623 5.176-1.332 9-6.03 9-11.622 0-1.31-.21-2.571-.598-3.751h-.152c-3.196 0-6.1-1.248-8.25-3.285z" />
            </svg>
            <h3 className="text-lg font-semibold text-white">Sync and checks</h3>
            <p className="mt-2 text-sm text-gray-400">
              ruly squash --sync mirrors one rules repo to every machine, with per-machine overrides:. Each squash that writes files checks for ambiguous anchor links and duplicate skill requires.
            </p>
          </div>
          <div className="card-glow rounded-lg border border-gray-800 bg-bg-secondary p-6 transition duration-200">
            <svg className="h-8 w-8 text-green-500 mb-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M14.25 6.087c0-.355.186-.676.401-.959.221-.29.349-.634.349-1.003 0-1.036-1.007-1.875-2.25-1.875s-2.25.84-2.25 1.875c0 .369.128.713.349 1.003.215.283.401.604.401.959v0a.64.64 0 01-.657.643 48.39 48.39 0 01-4.163-.3c.186 1.613.293 3.25.315 4.907a.656.656 0 01-.658.663v0c-.355 0-.676-.186-.959-.401a1.647 1.647 0 00-1.003-.349c-1.036 0-1.875 1.007-1.875 2.25s.84 2.25 1.875 2.25c.369 0 .713-.128 1.003-.349.283-.215.604-.401.959-.401v0c.31 0 .555.26.532.57a48.039 48.039 0 01-.642 5.056c1.518.19 3.058.309 4.616.354a.64.64 0 00.657-.643v0c0-.355-.186-.676-.401-.959a1.647 1.647 0 01-.349-1.003c0-1.035 1.008-1.875 2.25-1.875 1.243 0 2.25.84 2.25 1.875 0 .369-.128.713-.349 1.003-.215.283-.4.604-.4.959v0c0 .333.277.599.61.58a48.1 48.1 0 005.427-.63 48.05 48.05 0 00.582-4.717.532.532 0 00-.533-.57v0c-.355 0-.676.186-.959.401-.29.221-.634.349-1.003.349-1.035 0-1.875-1.007-1.875-2.25s.84-2.25 1.875-2.25c.37 0 .713.128 1.003.349.283.215.604.401.96.401v0a.656.656 0 00.658-.663 48.422 48.422 0 00-.37-5.36c-1.886.342-3.81.574-5.766.689a.578.578 0 01-.61-.58v0z" />
            </svg>
            <h3 className="text-lg font-semibold text-white">AGENTS.md and plugin output</h3>
            <p className="mt-2 text-sm text-gray-400">
              ruly squash RECIPE -a agents writes AGENTS.md, the cross-agent instruction file standard, and skips the Claude-only parts (commands, subagents, hooks, MCP servers). -a claude-plugin packages the skills, commands, agents, hooks and MCP servers as a plugin directory for claude --plugin-dir. Plugins cannot carry always-on instructions, so the rules ship as the skill /RECIPE:RECIPE-rules, loaded when invoked.
            </p>
          </div>
          <div className="card-glow rounded-lg border border-gray-800 bg-bg-secondary p-6 transition duration-200">
            <svg className="h-8 w-8 text-green-500 mb-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M3 13.125C3 12.504 3.504 12 4.125 12h2.25c.621 0 1.125.504 1.125 1.125v6.75C7.5 20.496 6.996 21 6.375 21h-2.25A1.125 1.125 0 013 19.875v-6.75zM9.75 8.625c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125v11.25c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V8.625zM16.5 4.125c0-.621.504-1.125 1.125-1.125h2.25C20.496 3 21 3.504 21 4.125v15.75c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V4.125z" />
            </svg>
            <h3 className="text-lg font-semibold text-white">Fixture benchmark</h3>
            <p className="mt-2 text-sm text-gray-400">
              On ruly&apos;s synthetic bench fixture (five recipes, cl100k_base tokens), the squashed recipe output plus its skill and command descriptions was a median 74.3% smaller than loading every rule, and 68.4% smaller than a native layout&apos;s always-loaded set. The numbers describe the synthetic fixture, not a real rules repo.{" "}
              <a
                href="https://github.com/patrickclery/ruly/blob/main/docs/benchmarks.md"
                className="text-green-400 hover:brightness-110 transition duration-200"
              >
                Benchmark details
              </a>
            </p>
          </div>
          <div className="card-glow rounded-lg border border-gray-800 bg-bg-secondary p-6 transition duration-200">
            <svg className="h-8 w-8 text-green-500 mb-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m5.231 13.481L15 17.25m-4.5-15H5.625c-.621 0-1.125.504-1.125 1.125v16.5c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9zm3.75 11.625a2.625 2.625 0 11-5.25 0 2.625 2.625 0 015.25 0z" />
            </svg>
            <h3 className="text-lg font-semibold text-white">Draft a recipe from a project</h3>
            <p className="mt-2 text-sm text-gray-400">
              The /recipe-from-project skill drafts a recipe from a project folder&apos;s current rules, skills, commands, subagents and MCP servers, and writes it to the rules repo&apos;s recipes.yml only after you approve the draft. It is not installed with the gem: list https://github.com/patrickclery/ruly/blob/main/skills/recipe-from-project.md under a recipe&apos;s skills: and ruly squash fetches it, so that squash needs the network.{" "}
              <a
                href="https://github.com/patrickclery/ruly#drafting-a-recipe-from-a-project"
                className="text-green-400 hover:brightness-110 transition duration-200"
              >
                How to run it
              </a>
            </p>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="border-t border-gray-800 py-8">
        <div className="mx-auto max-w-4xl px-4 flex flex-col items-center gap-4 sm:flex-row sm:justify-between">
          <div className="text-sm text-gray-500">
            <span className="font-mono break-all">
              curl -fsSL https://raw.githubusercontent.com/patrickclery/ruly/main/setup.rb -o /tmp/ruly_setup.rb &amp;&amp; ruby /tmp/ruly_setup.rb
            </span>
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
