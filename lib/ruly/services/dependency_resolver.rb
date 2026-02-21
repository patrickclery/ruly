# frozen_string_literal: true

module Ruly
  module Services
    # Resolves `requires:` and `skills:` frontmatter dependencies in rule files.
    # Handles both local file paths and remote GitHub URLs.
    module DependencyResolver # rubocop:disable Metrics/ModuleLength
      module_function

      # Resolve all `requires:` entries from a source's frontmatter.
      def resolve_requires_for_source(source, content, processed_files, _all_sources,
                                      find_rule_file:, gem_root:)
        frontmatter, = Services::FrontmatterParser.parse(content)
        requires = frontmatter['requires'] || []
        return [] if requires.empty?

        requires.filter_map do |required_path|
          resolved = resolve_required_path(source, required_path, find_rule_file:, gem_root:)
          next unless resolved

          key = get_source_key(resolved, find_rule_file:)
          next if processed_files.include?(key)

          resolved
        end
      end

      # Resolve all `skills:` entries from a source's frontmatter.
      # Unlike requires, missing skill files raise Ruly::Error.
      def resolve_skills_for_source(source, content, processed_files,
                                    find_rule_file:, gem_root:)
        frontmatter, = Services::FrontmatterParser.parse(content)
        skills = frontmatter['skills'] || []
        return [] if skills.empty?

        skills.filter_map do |skill_path|
          resolved = resolve_required_path(source, skill_path, find_rule_file:, gem_root:)
          validate_skill!(skill_path, resolved, source, find_rule_file)

          key = get_source_key(resolved, find_rule_file:)
          next if processed_files.include?(key)

          resolved.merge(from_skills: true)
        end
      end

      # Dispatch to local or remote resolver based on source type.
      def resolve_required_path(source, required_path, find_rule_file:, gem_root:)
        if source[:type] == 'local'
          resolve_local_require(source[:path], required_path, find_rule_file:, gem_root:)
        elsif source[:type] == 'remote'
          resolve_remote_require(source[:path], required_path)
        end
      end

      # Resolve a local require path relative to the source file.
      def resolve_local_require(source_path, required_path, find_rule_file:, gem_root:)
        source_full_path = find_rule_file.call(source_path)
        return nil unless source_full_path

        resolved_full_path = expand_local_path(source_full_path, required_path)
        return nil unless File.file?(resolved_full_path)

        canonical_path = File.realpath(resolved_full_path)
        relative_path = make_relative(canonical_path, gem_root)
        {path: relative_path, type: 'local'}
      end

      # Resolve a remote require path (GitHub URL or generic URL).
      def resolve_remote_require(source_url, required_path)
        if source_url.include?('github.com') && source_url.include?('/blob/')
          return resolve_github_require(source_url, required_path)
        end

        resolve_generic_remote_require(source_url, required_path)
      end

      # Normalize a path by resolving `.` and `..` segments.
      def normalize_path(path)
        path.split('/').each_with_object([]) do |part, parts|
          if part == '..'
            parts.pop
          elsif part != '.' && !part.empty?
            parts << part
          end
          parts
        end.join('/')
      end

      # Create a unique deduplication key for a source.
      def get_source_key(source, find_rule_file:)
        if source[:type] == 'local'
          full_path = find_rule_file.call(source[:path])
          full_path ? File.realpath(full_path) : source[:path]
        else
          source[:path]
        end
      end

      # --- private helpers (still module_function for internal use) ---

      def validate_skill!(skill_path, resolved, source, find_rule_file)
        raise Ruly::Error, "Skill file not found: '#{skill_path}' referenced from '#{source[:path]}'" unless resolved

        resolved_full_path = find_rule_file.call(resolved[:path])
        return if resolved_full_path&.include?('/skills/')

        raise Ruly::Error,
              "Skill reference '#{skill_path}' must be in a /skills/ directory " \
              "(resolved to '#{resolved[:path]}')"
      end

      def expand_local_path(source_full_path, required_path)
        source_dir = File.dirname(source_full_path)
        resolved = File.expand_path(required_path, source_dir)

        unless File.file?(resolved)
          md_path = "#{resolved}.md"
          resolved = md_path if !resolved.end_with?('.md') && File.file?(md_path)
        end
        resolved
      end

      def make_relative(canonical_path, gem_root)
        root_path = begin
          File.realpath(gem_root)
        rescue StandardError
          gem_root
        end

        if canonical_path.start_with?("#{root_path}/")
          canonical_path.sub("#{root_path}/", '')
        elsif canonical_path == root_path
          '.'
        else
          canonical_path
        end
      end

      def resolve_github_require(source_url, required_path)
        return nil unless source_url =~ %r{https://github\.com/([^/]+)/([^/]+)/blob/([^/]+)/(.+)}

        owner, repo, branch = Regexp.last_match(1), Regexp.last_match(2), Regexp.last_match(3)
        source_dir = File.dirname(Regexp.last_match(4))

        resolved_path = if required_path.start_with?('/')
                          required_path[1..]
                        else
                          normalize_path(File.join(source_dir, required_path))
                        end

        {path: "https://github.com/#{owner}/#{repo}/blob/#{branch}/#{resolved_path}", type: 'remote'}
      end

      def resolve_generic_remote_require(source_url, required_path)
        base_uri = URI.parse(source_url)
        resolved_uri = base_uri.dup
        resolved_uri.path = File.join(File.dirname(base_uri.path), required_path)
        {path: resolved_uri.to_s, type: 'remote'}
      rescue StandardError
        nil
      end
    end
  end
end
