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

      {/* Demo placeholder */}
      <section id="demo" className="mx-auto max-w-6xl px-4 py-16">
        <div className="rounded-lg border border-gray-800 bg-gray-900 p-8 text-center text-gray-500">
          Interactive demo coming soon...
        </div>
      </section>

      {/* Feature highlights placeholder */}
      <section className="mx-auto max-w-4xl px-4 py-16">
        <div className="text-center text-gray-500">Features coming soon...</div>
      </section>

      {/* Footer */}
      <footer className="border-t border-gray-800 py-8 text-center text-sm text-gray-500">
        <a href="https://github.com/patrickclery/ruly" className="hover:text-white transition">
          ruly
        </a>
        {" "}&mdash; A rule manager for Claude Code
      </footer>
    </main>
  );
}
