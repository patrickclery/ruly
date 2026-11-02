# frozen_string_literal: true

module RulyBench
  # The headless `claude -p` call a live compliance run makes. The prompt is never part of argv; it goes on stdin.
  module ClaudeCommand
    DEFAULT_MODEL = 'claude-sonnet-5-5'
    # The only built-in tool left on, in both conditions: skills must stay invocable for the skill task. Without
    # Read, Glob, Grep, Task/Agent, Web*, Bash or edit tools the model cannot look for rules on its own, so rules
    # reach it only through what Claude Code loads. --strict-mcp-config with no --mcp-config turns off MCP servers.
    TOOLS = 'Skill'
    FLAGS = %w[--model --output-format --setting-sources --no-session-persistence --max-budget-usd
               --strict-mcp-config --tools].freeze
    MODEL = /\A[\w.:-]+\z/

    module_function

    # @param model [String] model id
    # @param max_budget_usd [Numeric] per-call spending cap passed to claude
    # @param claude_bin [String] claude executable
    # @return [Array<String>]
    # @raise [RulyBench::Error] when the model id has characters outside [\w.:-]
    def argv(max_budget_usd:, model:, claude_bin: 'claude')
      raise Error, "invalid model id #{model.inspect}" unless model.is_a?(String) && model.match?(MODEL)

      [claude_bin, '-p', '--model', model, '--output-format', 'json', '--setting-sources', 'project,local',
       '--no-session-persistence', '--max-budget-usd', format('%.2f', max_budget_usd),
       '--strict-mcp-config', '--tools', TOOLS]
    end

    # @param help_text [String] output of `claude --help`
    # @return [Array<String>] one problem per flag the harness uses that the help text does not list
    def check_cli(help_text)
      (['--print'] + FLAGS).reject { |flag| help_text.match?(/(?<![\w-])#{Regexp.escape(flag)}(?![\w-])/) }
                           .map { |flag| "#{flag} is not listed" }
    end

    # Runs `claude_bin --help` (no API call) and checks every flag the harness uses.
    # @return [Array(Array<String>, Integer)] problems, and the number of flags checked
    def check_binary(claude_bin)
      help, = Open3.capture2e(claude_bin, '--help')
      help = help.dup.force_encoding(Encoding::UTF_8).scrub
      [check_cli(help).map { |problem| "#{claude_bin} --help: #{problem}" }, FLAGS.size + 1]
    rescue SystemCallError => e
      [["cannot run #{claude_bin} --help: #{e.class.name.split('::').last}"], 0]
    end
  end
end
