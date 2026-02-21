# frozen_string_literal: true

require 'tiktoken_ruby'

module Ruly
  module Services
    # Processes sources for the squash compilation pipeline.
    # Handles the main loop of iterating sources, deduplicating, resolving
    # requires/skills, and dispatching to local or remote file processors.
    module SourceProcessor # rubocop:disable Metrics/ModuleLength
      module_function

      # Main processing loop: prefetch remote files, iterate sources, deduplicate.
      # @param sources [Array<Hash>] source entries with :type and :path
      # @param agent [String] target agent name (e.g. 'claude')
      # @param find_rule_file [Proc] callable(path) returning absolute file path
      # @param gem_root [String] root path of the gem
      # @param verbose [Boolean] whether to show detailed output
      # @param keep_frontmatter [Boolean] whether to preserve non-metadata frontmatter
      # @param dry_run [Boolean] whether to skip side effects like copying bin files
      # @return [Array] [local_sources, command_files, bin_files, skill_files]
      def process_for_squash(sources, agent, find_rule_file:, gem_root:, # rubocop:disable Metrics/MethodLength
                             dry_run: false, keep_frontmatter: false, verbose: false)
        local_sources = []
        command_files = []
        bin_files = []
        skill_files = []
        processed_files = Set.new
        sources_to_process = sources.dup

        # Show total count
        puts "\n\u{1F4DA} Processing #{sources.length} sources..." if verbose

        # Prefetch remote files using GraphQL
        prefetched_content = Services::GitHubClient.prefetch_remote_files(sources, verbose:)

        # Process all sources including requires
        index = 0
        until sources_to_process.empty?
          source = sources_to_process.shift

          # Check if already processed (deduplication)
          source_key = get_source_key(source, find_rule_file:)
          next if processed_files.include?(source_key)

          # Process the source
          context = {
            agent:,
            find_rule_file:,
            gem_root:,
            keep_frontmatter:,
            prefetched_content:,
            processed_files:,
            sources_to_process:,
            verbose:
          }
          result = process_single_source_with_requires(source, index, sources.length + index, context)

          if result
            processed_files.add(source_key)

            if result[:is_bin]
              bin_files << result[:data]
            elsif result[:is_skill]
              skill_files << result[:data]
            elsif result[:is_command]
              command_files << result[:data]
            else
              local_sources << result[:data]
            end
          end

          index += 1
        end

        # Copy bin files to .ruly/bin if any exist
        Services::ScriptManager.copy_bin_files(bin_files) unless bin_files.empty? || dry_run

        puts if verbose

        [local_sources, command_files, bin_files, skill_files]
      end

      # Create a unique key for source deduplication.
      # For local files, resolves to the real absolute path.
      # For remote files, uses the full URL.
      # @param source [Hash] source entry with :type and :path
      # @param find_rule_file [Proc] callable(path) returning absolute file path
      # @return [String] unique key for the source
      def get_source_key(source, find_rule_file:)
        if source[:type] == 'local'
          full_path = find_rule_file.call(source[:path])

          if full_path
            File.realpath(full_path)
          else
            source[:path]
          end
        else
          source[:path]
        end
      end

      # Process one source with requires and skills resolution.
      # @param source [Hash] source entry
      # @param index [Integer] current index for progress display
      # @param total [Integer] total count for progress display
      # @param context [Hash] processing context with dependencies
      # @return [Hash, nil] result hash with :data, :is_command, :is_skill, :is_bin keys
      def process_single_source_with_requires(source, index, total, context) # rubocop:disable Metrics/MethodLength
        agent = context[:agent]
        find_rule_file = context[:find_rule_file]
        gem_root = context[:gem_root]
        prefetched_content = context[:prefetched_content]
        processed_files = context[:processed_files]
        sources_to_process = context[:sources_to_process]
        keep_frontmatter = context[:keep_frontmatter]
        verbose = context[:verbose]

        # First process the source normally
        result = process_single_source(source, index, total, agent, prefetched_content,
                                       find_rule_file:, keep_frontmatter:, verbose:)

        return nil unless result

        # If it's a regular markdown file (not bin), check for requires
        if !result[:is_bin] && result[:data] && result[:data][:content]
          # Use original content (with requires intact) for dependency resolution
          content_for_requires = result[:data][:original_content] || result[:data][:content]

          # For skill files, skip adding requires to the main queue -- they'll be
          # compiled into the skill output by save_skill_files instead
          unless result[:is_skill]
            # Resolve requires for this source
            required_sources = Services::DependencyResolver.resolve_requires_for_source(
              source, content_for_requires, processed_files, sources_to_process,
              find_rule_file:, gem_root:
            )

            # Add required sources to the front of the queue (depth-first processing)
            unless required_sources.empty?
              puts "    \u{2192} Found #{required_sources.length} requires, adding to queue..." if verbose
              required_sources.each { |rs| rs[:from_requires] = true }
              sources_to_process.unshift(*required_sources)
            end
          end

          # Resolve skills: frontmatter references (with validation)
          skill_sources = Services::DependencyResolver.resolve_skills_for_source(
            source, content_for_requires, processed_files,
            find_rule_file:, gem_root:
          )

          # Add skill sources to the queue -- they'll be categorized as skill_files
          # because their paths contain /skills/
          unless skill_sources.empty?
            puts "    \u{2192} Found #{skill_sources.length} skills, adding to queue..." if verbose
            sources_to_process.unshift(*skill_sources)
          end
        end

        result
      end

      # Dispatch to local or remote processor based on source type.
      # @param source [Hash] source entry
      # @param index [Integer] current index
      # @param total [Integer] total count
      # @param agent [String] target agent name
      # @param prefetched_content [Hash] map of URL -> content for prefetched remote files
      # @param find_rule_file [Proc] callable(path) returning absolute file path
      # @param keep_frontmatter [Boolean] whether to preserve non-metadata frontmatter
      # @param verbose [Boolean] whether to show detailed output
      # @return [Hash, nil] result hash or nil
      def process_single_source(source, index, total, agent, prefetched_content,
                                find_rule_file:, keep_frontmatter: false, verbose: false)
        if source[:type] == 'local'
          process_local_file(source, index, total, agent, find_rule_file:, keep_frontmatter:, verbose:)
        elsif prefetched_content[source[:path]]
          display_prefetched_remote(source, index, total, agent, prefetched_content[source[:path]],
                                    keep_frontmatter:, verbose:)
        else
          process_remote_file(source, index, total, agent, keep_frontmatter:, verbose:)
        end
      end

      # Process a local file source with progress display.
      # @param source [Hash] source entry with :path
      # @param index [Integer] current index
      # @param total [Integer] total count
      # @param agent [String] target agent name
      # @param find_rule_file [Proc] callable(path) returning absolute file path
      # @param keep_frontmatter [Boolean] whether to preserve non-metadata frontmatter
      # @param verbose [Boolean] whether to show detailed output
      # @return [Hash, nil] result hash or nil if file not found
      def process_local_file(source, index, total, agent,
                             find_rule_file:, keep_frontmatter: false, verbose: false)
        prefix = source[:from_requires] ? "\u{1F4DA} Required" : "\u{1F4C1} Local"
        print "  [#{index + 1}/#{total}] #{prefix}: #{source[:path]}..." if verbose
        file_path = find_rule_file.call(source[:path])

        unless file_path
          verbose ? puts(' \u{274C} not found') : warn("  \u{26A0}\u{FE0F}  File not found: #{source[:path]}")
          return nil
        end

        # Check if it's a bin/*.sh file
        is_bin = source[:path].match?(%r{bin/.*\.sh$}) || file_path.match?(%r{bin/.*\.sh$})

        if is_bin
          puts " \u{2705} (bin)" if verbose
          return {data: {relative_path: source[:path], source_path: file_path}, is_bin: true}
        end

        content = File.read(file_path, encoding: 'UTF-8')
        original_content = content
        content = Services::FrontmatterParser.strip_metadata(content, keep_frontmatter:)
        is_command = agent == 'claude' && (file_path.include?('/commands/') || source[:path].include?('/commands/'))
        is_skill = agent == 'claude' && source[:path].include?('/skills/')

        tokens = count_tokens(content)
        formatted_tokens = format_token_count(tokens)

        print_file_progress(formatted_tokens, from_requires: source[:from_requires], is_command:, is_skill:,
                                              verbose:)
        {data: {content:, original_content:, path: source[:path]}, is_command:, is_skill:}
      end

      # Display and process prefetched remote content.
      # @param source [Hash] source entry with :path
      # @param index [Integer] current index
      # @param total [Integer] total count
      # @param agent [String] target agent name
      # @param content [String] prefetched content
      # @param keep_frontmatter [Boolean] whether to preserve non-metadata frontmatter
      # @param verbose [Boolean] whether to show detailed output
      # @return [Hash] result hash
      def display_prefetched_remote(source, index, total, agent, content,
                                    keep_frontmatter: false, verbose: false)
        if source[:path] =~ %r{https?://github\.com/([^/]+)/([^/]+)/(?:blob|tree)/[^/]+/(.+)}
          owner = Regexp.last_match(1)
          repo = Regexp.last_match(2)
          file_path = Regexp.last_match(3)
          display_name = "#{owner}/#{repo}/#{file_path}"
          icon = source[:from_requires] ? "\u{1F4DA}" : "\u{1F419}"
        else
          display_name = source[:path]
          icon = source[:from_requires] ? "\u{1F4DA}" : "\u{1F4E6}"
        end

        prefix = source[:from_requires] ? 'Required' : 'Processing'
        print "  [#{index + 1}/#{total}] #{icon} #{prefix}: #{display_name}..." if verbose

        original_content = content
        content = Services::FrontmatterParser.strip_metadata(content, keep_frontmatter:)

        tokens = count_tokens(content)
        formatted_tokens = format_token_count(tokens)

        is_command = agent == 'claude' && source[:path].include?('/commands/')
        is_skill = agent == 'claude' && source[:path].include?('/skills/')
        print_file_progress(formatted_tokens, from_requires: source[:from_requires], is_command:, is_skill:,
                                              verbose:)

        {data: {content:, original_content:, path: source[:path]}, is_command:, is_skill:}
      end

      # Process a remote file with individual fetch (fallback when not prefetched).
      # @param source [Hash] source entry with :path
      # @param index [Integer] current index
      # @param total [Integer] total count
      # @param agent [String] target agent name
      # @param keep_frontmatter [Boolean] whether to preserve non-metadata frontmatter
      # @param verbose [Boolean] whether to show detailed output
      # @return [Hash, nil] result hash or nil if fetch failed
      def process_remote_file(source, index, total, agent, keep_frontmatter: false, verbose: false)
        display_info = parse_remote_display_info(source[:path], from_requires: source[:from_requires])
        prefix = source[:from_requires] ? 'Required' : 'Fetching'
        print "  [#{index + 1}/#{total}] #{display_info[:icon]} #{prefix}: #{display_info[:display_name]}..." if verbose
        content = Services::GitHubClient.fetch_remote_content(source[:path])

        unless content
          verbose ? puts(' \u{274C} failed') : warn("  \u{26A0}\u{FE0F}  Failed to fetch: #{source[:path]}")
          return nil
        end

        original_content = content
        content = Services::FrontmatterParser.strip_metadata(content, keep_frontmatter:)

        tokens = count_tokens(content)
        formatted_tokens = format_token_count(tokens)

        is_command = agent == 'claude' && source[:path].include?('/commands/')
        is_skill = agent == 'claude' && source[:path].include?('/skills/')
        print_file_progress(formatted_tokens, from_requires: source[:from_requires], is_command:, is_skill:,
                                              verbose:)
        {data: {content:, original_content:, path: source[:path]}, is_command:, is_skill:}
      end

      # Format a remote URL for display.
      # @param path [String] remote URL
      # @param from_requires [Boolean] whether the source is from a requires directive
      # @return [Hash] hash with :display_name and :icon
      def parse_remote_display_info(path, from_requires: false)
        if path =~ %r{https?://github\.com/([^/]+)/([^/]+)/(?:blob|tree)/[^/]+/(.+)}
          display_name = "#{Regexp.last_match(1)}/#{Regexp.last_match(2)}/#{Regexp.last_match(3)}"
          icon = from_requires ? "\u{1F4DA}" : "\u{1F419}"
        elsif path =~ %r{https?://([^/]+)/(.+)}
          display_name = "#{Regexp.last_match(1)}/#{Regexp.last_match(2)}"
          icon = from_requires ? "\u{1F4DA}" : "\u{1F310}"
        else
          display_name = path
          icon = from_requires ? "\u{1F4DA}" : "\u{1F310}"
        end
        {display_name:, icon:}
      end

      # Count tokens in text using cl100k_base encoding.
      # @param text [String] text to count tokens for
      # @return [Integer] token count
      def count_tokens(text)
        encoder = Tiktoken.get_encoding('cl100k_base')
        utf8_text = text.encode('UTF-8', invalid: :replace, replace: '?', undef: :replace)
        encoder.encode(utf8_text).length
      end

      # Format a token count with comma separators.
      # @param tokens [Integer] token count
      # @return [String] formatted token count
      def format_token_count(tokens)
        tokens.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\\1,')
      end

      # Print progress result for a processed file.
      # @param formatted_tokens [String] formatted token count
      # @param from_requires [Boolean] whether from a requires directive
      # @param is_command [Boolean] whether this is a command file
      # @param is_skill [Boolean] whether this is a skill file
      # @param verbose [Boolean] whether to show output
      def print_file_progress(formatted_tokens, from_requires:, is_command:, is_skill:, verbose: false)
        return unless verbose

        label = if is_skill then 'skill'
                elsif is_command then 'command'
                elsif from_requires then 'from requires'
                end
        suffix = label ? "(#{label}, #{formatted_tokens} tokens)" : "(#{formatted_tokens} tokens)"
        puts " \u{2705} #{suffix}"
      end
    end
  end
end
