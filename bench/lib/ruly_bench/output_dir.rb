# frozen_string_literal: true

module RulyBench
  # Where benchmark results may be written. A non-fixture corpus may be private: its results never go under
  # bench/results/ outside the git-ignored bench/results/local/.
  module OutputDir
    module_function

    # @param corpus [RulyBench::Corpus]
    # @param repo_root [String]
    # @param requested [String, nil] the --output-dir option
    # @return [String] the resolved output dir (default bench/results, or bench/results/local for a non-fixture corpus)
    def resolve(corpus:, repo_root:, requested: nil)
      default = corpus.fixture? ? 'bench/results' : 'bench/results/local'
      real_path(requested || File.join(repo_root, default))
    end

    # @return [Boolean] true when a non-fixture corpus would write under bench/results/ outside bench/results/local/
    def forbidden?(corpus:, output_dir:, repo_root:)
      return false if corpus.fixture?

      results = real_path(File.join(repo_root, 'bench/results'))
      local = real_path(File.join(repo_root, 'bench/results/local'))
      inside?(output_dir, results) && !inside?(output_dir, local)
    end

    # @return [String] the refusal message for a forbidden output dir
    def refusal(output_dir)
      "refusing to write results of a non-fixture corpus to #{output_dir}; " \
        'use bench/results/local (git-ignored) or a directory outside bench/results'
    end

    # Expand a path and resolve symlinks through its nearest existing ancestor (the path may not exist yet).
    def real_path(path)
      path = File.expand_path(path)
      missing = []
      until File.exist?(path) || path == File.dirname(path)
        missing.unshift(File.basename(path))
        path = File.dirname(path)
      end
      File.join(File.realpath(path), *missing)
    end

    def inside?(path, dir)
      path == dir || path.start_with?("#{dir}/")
    end
  end
end
