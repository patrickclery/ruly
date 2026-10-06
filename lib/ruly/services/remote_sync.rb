# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'
require 'yaml'

module Ruly
  module Services
    # Mirrors a remote recipes.yml and every rule file it references into
    # ~/.config/ruly/remotes/<owner>/<repo>/, preserving repo-relative paths.
    #
    # After a sync, every machine that runs `ruly squash --sync` has an identical
    # local copy of the shared recipes and their rule files, so squash output no
    # longer depends on machine-specific absolute paths.
    module RemoteSync # rubocop:disable Metrics/ModuleLength
      module_function

      RULE_KEYS = %w[files skills commands scripts].freeze
      DEFAULT_PATH = 'recipes.yml'
      DEFAULT_BRANCH = 'main'
      BATCH_SIZE = 50
      RULE_EXTENSIONS = %w[.md .mdc .sh].freeze

      # Root directory that holds one mirror per owner/repo.
      # @return [String]
      def remotes_dir
        File.join(Dir.home, '.config', 'ruly', 'remotes')
      end

      # Repos already synced during this process (avoid re-fetching when
      # load_all_recipes is called several times per command).
      # @return [Set<String>]
      def synced_repos
        @synced_repos ||= Set.new
      end

      # @return [void]
      def reset_synced_repos!
        @synced_repos = Set.new
      end

      # Normalize a `remotes:` entry into a remote spec.
      #
      # @param entry [Hash, String] `{github: 'owner/repo', path:, branch:}` or `'owner/repo'`
      # @param remotes_dir [String] root directory for mirrors
      # @return [Hash] `{github:, branch:, path:, mirror_dir:}`
      # @raise [Ruly::Error] when the entry has no usable owner/repo
      def normalize_remote(entry, remotes_dir: self.remotes_dir)
        hash = entry.is_a?(String) ? {'github' => entry} : (entry || {})
        repo = hash['github'].to_s.delete_prefix('github:')
                              .sub(%r{\Ahttps?://github\.com/}, '').delete_suffix('.git').delete_suffix('/')
        owner, name = repo.split('/', 2)
        if owner.nil? || owner.empty? || name.nil? || name.empty? || name.include?('/')
          raise Ruly::Error, "Invalid remote #{entry.inspect}: expected `github: owner/repo`"
        end

        {
          branch: hash['branch'] || DEFAULT_BRANCH,
          github: "#{owner}/#{name}",
          mirror_dir: File.join(remotes_dir, owner, name),
          path: hash['path'] || DEFAULT_PATH
        }
      end

      # Path of the mirrored recipes file for a remote.
      # @param remote [Hash] normalized remote spec
      # @return [String]
      def mirror_recipes_file(remote)
        File.join(remote[:mirror_dir], remote[:path])
      end

      # Whether the remote has been mirrored locally.
      # @param remote [Hash] normalized remote spec
      # @return [Boolean]
      def mirrored?(remote)
        File.exist?(mirror_recipes_file(remote))
      end

      # Mirrors present on disk that are not in the declared list.
      # @param declared [Array<Hash>] normalized remote specs
      # @param remotes_dir [String]
      # @return [Array<Hash>] normalized remote specs for undeclared mirrors
      def undeclared_mirrors(declared, remotes_dir: self.remotes_dir)
        declared_repos = declared.to_set { |r| r[:github] }
        Dir.glob(File.join(remotes_dir, '*', '*', DEFAULT_PATH)).filter_map do |file|
          name = File.basename(File.dirname(file))
          owner = File.basename(File.dirname(file, 2))
          repo = "#{owner}/#{name}"
          next if declared_repos.include?(repo)

          normalize_remote({'github' => repo}, remotes_dir:)
        end
      end

      # Sync every declared remote once per process.
      # @param remotes [Array<Hash>] normalized remote specs
      # @return [void]
      def sync_all!(remotes)
        remotes.each do |remote|
          next if synced_repos.include?(remote[:github])

          sync!(remote)
          synced_repos << remote[:github]
        end
      end

      # Fetch the remote recipes file and the closure of rule files it needs,
      # then atomically replace the mirror directory.
      #
      # @param remote [Hash] normalized remote spec
      # @return [Hash, nil] `{count:, mirror_dir:}` or nil when an existing mirror was kept
      # @raise [Ruly::Error] when the recipes file or any referenced file cannot be fetched
      def sync!(remote)
        label = "#{remote[:github]}/#{remote[:path]}@#{remote[:branch]}"
        puts "\u{1F504} Syncing #{label}..."

        # Prefer gh; fall back to a shallow git clone when gh cannot authenticate
        # (e.g. its token lives in a macOS keychain that is locked over SSH) or cannot fetch.
        clone = nil
        yaml = gh_available? ? read_remote_file(remote, remote[:path], clone: nil) : nil
        if yaml.nil?
          clone = clone_repo(remote)
          yaml = read_remote_file(remote, remote[:path], clone:) if clone
        end
        unless yaml
          if mirrored?(remote)
            warn "  \u{26A0}\u{FE0F}  Could not fetch #{label}; keeping existing mirror at #{remote[:mirror_dir]}"
            return nil
          end
          raise Ruly::Error,
                "Could not fetch #{label} (check `gh auth status`, or that `git clone` of the repo works)"
        end

        config = YAML.safe_load(yaml, aliases: true) || {}
        seeds = collect_seed_paths(config)
        files = fetch_closure(remote, seeds, clone:)
        files[remote[:path]] = yaml
        write_mirror(remote, files)

        puts "  \u{2705} Mirrored #{files.size} files to #{remote[:mirror_dir]}" \
             "#{' (via git clone)' if clone}"
        {count: files.size, mirror_dir: remote[:mirror_dir]}
      ensure
        FileUtils.rm_rf(clone) if clone
      end

      # Whether the gh CLI can authenticate (its token may live in a keychain that is
      # unavailable over SSH, or be expired).
      # @return [Boolean]
      def gh_available?
        system('gh auth token', err: File::NULL, out: File::NULL) ? true : false
      end

      # Shallow-clone the remote into a temp dir, trying SSH then HTTPS.
      # @param remote [Hash]
      # @return [String, nil] clone directory, or nil when every attempt failed
      def clone_repo(remote)
        dir = Dir.mktmpdir('ruly-sync-clone-')
        urls = ["git@github.com:#{remote[:github]}.git", "https://github.com/#{remote[:github]}.git"]
        urls.each do |url|
          FileUtils.rm_rf(dir)
          ok = system('git', 'clone', '--quiet', '--depth', '1', '--branch', remote[:branch], '--single-branch',
                      url, dir, err: File::NULL, out: File::NULL)
          if ok
            puts "  \u{1F4E6} Cloned #{url} (gh unavailable)"
            return dir
          end
        end
        FileUtils.rm_rf(dir)
        nil
      end

      # Read one repo-relative file from the clone or via gh.
      # @return [String, nil]
      def read_remote_file(remote, path, clone:)
        if clone
          full = File.join(clone, path)
          File.file?(full) ? File.read(full, encoding: 'UTF-8') : nil
        else
          GitHubClient.fetch_remote_content(blob_url(remote, path))
        end
      end

      # Every repo-relative path named directly by a recipe in the config.
      # @param config [Hash] parsed recipes.yml
      # @return [Array<String>] unique relative paths (files or directories)
      def collect_seed_paths(config)
        paths = []
        (config['recipes'] || {}).each_value do |recipe|
          entries = if recipe.is_a?(Array)
                      recipe
                    else
                      RULE_KEYS.flat_map do |k|
                        Array(recipe.is_a?(Hash) ? recipe[k] : nil)
                      end
                    end
          entries.each { |e| paths << normalize_relative(e) if relative_entry?(e) }
        end
        paths.uniq
      end

      # Whether a recipe entry is a repo-relative path (not absolute, ~, or a URL).
      # @param entry [Object]
      # @return [Boolean]
      def relative_entry?(entry)
        return false unless entry.is_a?(String) && !entry.strip.empty?

        !(File.absolute_path?(entry) || entry.start_with?('~', 'http://', 'https://', 'github:'))
      end

      # Strip leading './' and collapse '..' segments.
      # @param path [String]
      # @return [String]
      def normalize_relative(path)
        DependencyResolver.normalize_path(path)
      end

      # Fetch the given paths plus everything they transitively `requires:`/`skills:`.
      #
      # @param remote [Hash] normalized remote spec
      # @param seeds [Array<String>] relative paths (files or directories)
      # @return [Hash{String => String}] relative path => content
      # @raise [Ruly::Error] listing every explicitly-listed path that could not be fetched
      def fetch_closure(remote, seeds, clone: nil)
        files = {}
        missing = []
        transitive_missing = []
        queue = expand_directories(remote, seeds, missing, clone:)
        explicit = queue.to_set

        until queue.empty?
          batch = queue.shift(BATCH_SIZE).reject { |p| files.key?(p) }
          next if batch.empty?

          fetched = fetch_batch(remote, batch, clone:)
          batch.each do |path|
            content = fetched[path]
            if content.nil?
              (explicit.include?(path) ? missing : transitive_missing) << path
              next
            end

            files[path] = content
            queue.concat(dependencies_of(path, content).reject { |d| files.key?(d) || queue.include?(d) })
          end
        end

        warn_transitive_missing(transitive_missing)
        raise_missing!(remote, missing) unless missing.empty?
        files
      end

      # Missing `requires:`/`skills:` targets mirror squash's leniency for transitive
      # sources: warn, but do not abort the sync.
      # @param paths [Array<String>]
      # @return [void]
      def warn_transitive_missing(paths)
        return if paths.empty?

        warn "  \u{26A0}\u{FE0F}  #{paths.uniq.size} file(s) referenced only via requires:/skills: were not found " \
             '(squash will skip them):'
        paths.uniq.each { |p| warn "     \u{2717} #{p}" }
      end

      # Expand directory seeds (no extension) into their file paths via the GitHub API.
      # @param remote [Hash]
      # @param seeds [Array<String>]
      # @param missing [Array<String>] accumulator for directories that could not be listed
      # @return [Array<String>] file paths
      def expand_directories(remote, seeds, missing, clone: nil)
        seeds.flat_map do |path|
          next [path] if /\.\w+\z/.match?(path)

          listed = list_remote_directory(remote, path, clone:)
          if listed.nil?
            missing << "#{path}/ (directory listing failed)"
            []
          else
            listed
          end
        end.uniq
      end

      # Repo-relative file paths under a directory (files with rule extensions, recursive).
      # @return [Array<String>, nil] nil when the listing failed
      def list_remote_directory(remote, path, clone: nil)
        unless clone
          return GitHubClient.list_github_directory(remote[:github], remote[:branch], path,
                                                    extensions: RULE_EXTENSIONS, recursive: true)
        end

        base = File.join(clone, path)
        return nil unless File.directory?(base)

        Dir.glob(File.join(base, '**', '*')).select { |f| File.file?(f) && RULE_EXTENSIONS.any? { |e| f.end_with?(e) } }
           .map { |f| f.delete_prefix("#{clone}/") }
      end

      # Fetch a batch of files: from the clone, or GraphQL first then one-by-one for misses.
      # @param remote [Hash]
      # @param paths [Array<String>]
      # @return [Hash{String => String}] relative path => content (misses omitted)
      def fetch_batch(remote, paths, clone: nil)
        return paths.to_h { |p| [p, read_remote_file(remote, p, clone:)] }.compact if clone

        sources = paths.map { |p| {path: blob_url(remote, p)} }
        by_url = GitHubClient.fetch_github_files_graphql(remote[:github], sources) || {}

        paths.each_with_object({}) do |path, result|
          url = blob_url(remote, path)
          content = by_url[url] || GitHubClient.fetch_remote_content(url)
          result[path] = content if content
        end
      end

      # Relative paths a rule file depends on through frontmatter `requires:` and `skills:`.
      # Resolution mirrors DependencyResolver.resolve_github_require: relative to the
      # file's directory, or repo-root relative when the entry starts with '/'.
      #
      # @param path [String] repo-relative path of the file
      # @param content [String] file content
      # @return [Array<String>] repo-relative dependency paths
      def dependencies_of(path, content)
        frontmatter, = FrontmatterParser.parse(content)
        deps = Array(frontmatter['requires']) + Array(frontmatter['skills'])
        dir = File.dirname(path)

        deps.filter_map do |dep|
          next unless dep.is_a?(String)
          next if dep.start_with?('http://', 'https://')

          resolved = dep.start_with?('/') ? dep[1..] : File.join(dir, dep)
          resolved = normalize_relative(resolved)
          resolved = "#{resolved}.md" unless /\.\w+\z/.match?(resolved)
          resolved
        end
      end

      # Write files into a temp dir next to the mirror, then swap it in.
      # A failed write leaves the previous mirror untouched.
      #
      # @param remote [Hash]
      # @param files [Hash{String => String}]
      # @return [void]
      def write_mirror(remote, files)
        parent = File.dirname(remote[:mirror_dir])
        FileUtils.mkdir_p(parent)
        tmp = Dir.mktmpdir(".sync-#{File.basename(remote[:mirror_dir])}-", parent)

        files.each do |rel, content|
          target = File.join(tmp, rel)
          FileUtils.mkdir_p(File.dirname(target))
          File.write(target, content)
        end

        FileUtils.rm_rf(remote[:mirror_dir])
        FileUtils.mv(tmp, remote[:mirror_dir])
      rescue StandardError
        FileUtils.rm_rf(tmp) if tmp && Dir.exist?(tmp)
        raise
      end

      # GitHub blob URL for a repo-relative path.
      # @param remote [Hash]
      # @param path [String]
      # @return [String]
      def blob_url(remote, path)
        "https://github.com/#{remote[:github]}/blob/#{remote[:branch]}/#{path}"
      end

      # @raise [Ruly::Error]
      def raise_missing!(remote, missing)
        list = missing.uniq.map { |m| "  \u{2717} #{m}" }.join("\n")
        raise Ruly::Error,
              "Sync of #{remote[:github]} aborted: #{missing.uniq.size} referenced file(s) could not be fetched:\n" \
              "#{list}\nFix the paths in #{remote[:path]} (or push the missing files) and re-run --sync."
      end
    end
  end
end
