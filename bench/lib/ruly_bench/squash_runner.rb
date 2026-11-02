# frozen_string_literal: true

module RulyBench
  # Runs the real `bin/ruly squash RECIPE` on a temp copy of a corpus, with HOME and RULY_HOME pointed
  # at temp dirs so the developer's ~/.config/ruly and the repo's rules/ cannot affect the result.
  module SquashRunner
    RECIPE_NAME = /\A[\w.-]+\z/
    OUTPUT_TAIL_LINES = 20

    # Raised when the squash subprocess exits non-zero; carries the exit status.
    class SquashFailed < Error
      attr_reader :exit_status

      def initialize(message, exit_status)
        super(message)
        @exit_status = exit_status
      end
    end

    module_function

    # @param corpus_dir [String] corpus root (holds recipes.yml)
    # @param recipe [String] recipe name
    # @yieldparam result [Hash] 'claude_local_md' (String) and 'descriptors' (sorted Array<String>)
    # @return the block's value; the temp workspace is removed when the block returns
    # @raise [RulyBench::Error] on an invalid recipe name or a failed squash
    def run(corpus_dir:, recipe:)
      raise Error, "invalid recipe name #{recipe.inspect}" unless recipe.is_a?(String) && recipe.match?(RECIPE_NAME)

      Dir.mktmpdir('ruly-bench') do |tmp|
        home = File.join(tmp, 'home')
        work = File.join(tmp, 'work')
        prepare_workspace(corpus_dir, home, work)
        squash!(recipe, home, work)
        yield collect(work)
      end
    end

    def prepare_workspace(corpus_dir, home, work)
      FileUtils.mkdir_p([home, work])
      Dir.children(corpus_dir).sort.each do |entry|
        next if entry == '.git'

        FileUtils.cp_r(File.join(corpus_dir, entry), work)
      end
      FileUtils.cp(File.join(work, 'recipes.yml'), File.join(work, '.recipes.yml'))
    end

    def squash!(recipe, home, work)
      env = {
        'BUNDLE_GEMFILE' => File.join(REPO_ROOT, 'Gemfile'),
        'HOME' => home,
        'RULY_HOME' => work
      }
      argv = [RbConfig.ruby, '-rbundler/setup', File.join(REPO_ROOT, 'bin/ruly'), 'squash', recipe]
      output, status = Open3.capture2e(env, *argv, chdir: work)
      return if status.success?

      tail = output.lines.last(OUTPUT_TAIL_LINES).join
      raise SquashFailed.new("ruly squash #{recipe} failed (exit #{status.exitstatus}):\n#{tail}", status.exitstatus)
    end

    def collect(work)
      claude_local = File.join(work, 'CLAUDE.local.md')
      {
        'claude_local_md' => File.file?(claude_local) ? File.read(claude_local) : '',
        'descriptors' => (skill_descriptors(work) + command_descriptors(work)).sort
      }
    end

    def skill_descriptors(work)
      Dir.glob('.claude/skills/*/SKILL.md', base: work).map do |rel|
        descriptor(File.read(File.join(work, rel)), File.basename(File.dirname(rel)))
      end
    end

    def command_descriptors(work)
      Dir.glob('.claude/commands/**/*.md', base: work).map do |rel|
        descriptor(File.read(File.join(work, rel)), File.basename(rel, '.md'))
      end
    end

    def descriptor(content, fallback_name)
      Corpus.descriptor(content, fallback_name)
    end
  end
end
