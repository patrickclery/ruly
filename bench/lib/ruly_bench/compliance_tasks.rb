# frozen_string_literal: true

module RulyBench
  # The compliance task suite: loads `tasks:` from YAML and validates every task against a corpus.
  class ComplianceTasks
    ID = /\A[a-z0-9-]+\z/
    KEYS = %w[id recipe rule_file rule_marker prompt checks example_pass example_fail].freeze
    MAX_TASKS = 10

    attr_reader :corpus, :tasks

    # @param path [String] YAML file with a `tasks:` list
    # @param corpus [RulyBench::Corpus]
    # @raise [RulyBench::Error] when the file is missing or has no `tasks:` list
    def initialize(corpus:, path:)
      raise Error, "no task file #{path}" unless File.file?(path)

      data = YAML.safe_load_file(path)
      @tasks = data.is_a?(Hash) ? data['tasks'] : nil
      raise Error, "#{File.basename(path)} has no tasks: list" unless @tasks.is_a?(Array)

      @corpus = corpus
    end

    # @return [Array<String>] every problem in the suite (empty = valid)
    def validate
      suite_problems + tasks.flat_map { |task| task_problems(task) }
    end

    # @return [Array<String>] problems of the suite as a whole (task count, ids)
    def suite_problems
      problems = []
      problems << "expected 1 to #{MAX_TASKS} tasks, found #{tasks.size}" unless (1..MAX_TASKS).cover?(tasks.size)
      ids = tasks.map { |task| task.is_a?(Hash) ? task['id'] : nil }
      ids.tally.each { |id, count| problems << "duplicate task id #{id}" if count > 1 && id }
      problems
    end

    # @param task [Hash]
    # @return [Array<String>] problems of one task, each prefixed with its id
    def task_problems(task)
      return ['task is not a mapping'] unless task.is_a?(Hash)

      missing = KEYS.reject { |key| task.key?(key) }
      problems = missing.map { |key| "missing key #{key}" }
      problems.concat(field_problems(task)) if missing.empty?
      problems.map { |problem| "#{task['id'] || '(no id)'}: #{problem}" }
    end

    private

    def field_problems(task)
      problems = []
      problems << "invalid id #{task['id'].inspect}" unless task['id'].to_s.match?(ID)
      problems << "unknown recipe #{task['recipe']}" unless corpus.recipes.key?(task['recipe'].to_s)
      problems.concat(marker_problems(task))
      check_problems = Array(task['checks']).empty? ? ['no checks'] : task['checks'].flat_map { check_problems(_1) }
      problems.concat(check_problems)
      problems.concat(example_problems(task)) if check_problems.empty?
      problems
    end

    def marker_problems(task)
      marker = task['rule_marker'].to_s.strip
      path = File.join(corpus.dir, task['rule_file'].to_s)
      return ["rule_file #{task['rule_file']} not in corpus"] unless File.file?(path)
      return ["rule_marker is not a line of #{task['rule_file']}"] unless marker_line?(path, marker)
      return ['prompt contains the rule_marker'] if task['prompt'].to_s.downcase.include?(marker.downcase)

      []
    end

    def marker_line?(path, marker)
      !marker.empty? && File.readlines(path).any? { |line| line.strip == marker }
    end

    def check_problems(check)
      return ["check is not a mapping: #{check.inspect}"] unless check.is_a?(Hash)

      problems = []
      problems << "check type #{check['type'].inspect} not forbid/require" unless Scorer::TYPES.include?(check['type'])
      problems << "check scope #{check['scope'].inspect} not code/first_line/text" unless Scorer::SCOPES.include?(
        check['scope']
      )
      problems.concat(pattern_problems(check['pattern']))
    end

    def pattern_problems(pattern)
      return ['check pattern is not a string'] unless pattern.is_a?(String)

      Regexp.new(pattern)
      []
    rescue RegexpError => e
      ["check pattern /#{pattern}/ does not compile: #{e.message}"]
    end

    def example_problems(task)
      problems = []
      passing = Scorer.score(task['example_pass'].to_s, task['checks'])
      problems << "example_pass fails #{passing[:failed].join(', ')}" unless passing[:pass]
      problems << 'example_fail passes every check' if Scorer.score(task['example_fail'].to_s, task['checks'])[:pass]
      problems
    end
  end
end
