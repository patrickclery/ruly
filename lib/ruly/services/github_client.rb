# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'
require 'base64'
require 'tempfile'
require 'fileutils'

module Ruly
  module Services
    # GitHub integration methods for fetching remote files via GraphQL, REST API,
    # and gh CLI. All methods are stateless module functions.
    module GitHubClient # rubocop:disable Metrics/ModuleLength
      module_function

      # Fetch directory contents from a GitHub tree URL.
      # @param url [String] GitHub directory URL (https://github.com/owner/repo/tree/branch/path)
      # @return [Array<String>] List of blob URLs for .md files in the directory
      def fetch_github_directory_files(url)
        return [] unless url =~ %r{github\.com/([^/]+)/([^/]+)/tree/([^/]+)/(.+)}

        owner = Regexp.last_match(1)
        repo = Regexp.last_match(2)
        branch = Regexp.last_match(3)
        path = Regexp.last_match(4)

        result = `gh api repos/#{owner}/#{repo}/contents/#{path}?ref=#{branch} 2>/dev/null`

        if $CHILD_STATUS.success? && !result.empty?
          begin
            items = JSON.parse(result)

            md_files = items.select do |item|
              item['type'] == 'file' && item['name'].end_with?('.md')
            end

            md_files.map do |file|
              "https://github.com/#{owner}/#{repo}/blob/#{branch}/#{path}/#{file['name']}"
            end
          rescue JSON::ParserError => e
            puts "\u26a0\ufe0f  Error parsing GitHub directory response: #{e.message}"
            []
          end
        else
          puts "\u26a0\ufe0f  Failed to fetch directory contents from: #{url}"
          []
        end
      rescue StandardError => e
        puts "\u26a0\ufe0f  Error fetching GitHub directory: #{e.message}"
        []
      end

      # Normalize GitHub URLs. Converts shorthand github:org/repo/path to full URL.
      # @param url [String] URL or github: shorthand
      # @return [String] Full GitHub URL
      def normalize_github_url(url)
        if url.start_with?('github:')
          path = url.sub('github:', '')
          "https://github.com/#{path}"
        else
          url
        end
      end

      # Batch fetch files from a GitHub repository using GraphQL.
      # @param repo_key [String] "owner/repo" string
      # @param repo_sources [Array<Hash>] Array of source hashes with :path keys
      # @return [Hash, nil] Map of source paths to file contents, or nil on failure
      def fetch_github_files_graphql(repo_key, repo_sources)
        owner, repo = repo_key.split('/')

        query = build_graphql_files_query(owner, repo, repo_sources)

        response = execute_github_graphql(query)
        unless response
          puts '    Debug: No response from GraphQL' if ENV['DEBUG']
          return nil
        end

        result = parse_graphql_files_response(response, repo_sources)
        puts "    Debug: Parsed #{result.size} files from GraphQL" if ENV['DEBUG']
        result
      rescue StandardError => e
        puts "  \u26a0\ufe0f  GraphQL fetch failed: #{e.message}"
        nil
      end

      # Build a GraphQL query to fetch multiple files from a repository.
      # @param owner [String] Repository owner
      # @param repo [String] Repository name
      # @param sources [Array<Hash>] Array of source hashes with :path keys
      # @return [String] GraphQL query string
      def build_graphql_files_query(owner, repo, sources)
        file_queries = sources.map.with_index do |source, idx|
          if source[:path] =~ %r{/(?:blob|tree)/([^/]+)/(.+)}
            branch = Regexp.last_match(1)
            file_path = Regexp.last_match(2)
            "file#{idx}: object(expression: \"#{branch}:#{file_path}\") { ... on Blob { text } }"
          end
        end.compact

        <<~GRAPHQL
          query {
            repository(owner: "#{owner}", name: "#{repo}") {
              #{file_queries.join("\n    ")}
            }
          }
        GRAPHQL
      end

      # Execute a GraphQL query against the GitHub API using gh CLI.
      # @param query [String] GraphQL query string
      # @return [Hash, nil] Parsed JSON response, or nil on failure
      def execute_github_graphql(query)
        file = Tempfile.new(['graphql', '.txt'])
        file.write(query)
        file.close

        result = `gh api graphql -f query="$(cat #{file.path})" 2>&1`
        file.unlink

        return nil unless $CHILD_STATUS.success?

        result.force_encoding('UTF-8')

        JSON.parse(result)
      rescue StandardError => e
        puts "    Debug: GraphQL execution error: #{e.message}" if ENV['DEBUG']
        nil
      end

      # Parse a GraphQL files response and map results back to source paths.
      # @param response [Hash] Parsed GraphQL JSON response
      # @param sources [Array<Hash>] Original source hashes
      # @return [Hash] Map of source paths to file text content
      def parse_graphql_files_response(response, sources)
        return {} unless response['data'] && response['data']['repository']

        results = {}
        repo_data = response['data']['repository']

        sources.each_with_index do |source, idx|
          file_data = repo_data["file#{idx}"]
          results[source[:path]] = file_data['text'] if file_data && file_data['text']
        end

        results
      end

      # Fetch content from a remote URL, trying gh CLI first for GitHub URLs.
      # @param url [String] URL to fetch content from
      # @return [String, nil] File content, or nil on failure
      def fetch_remote_content(url)
        if url.include?('github.com')
          content = fetch_via_gh_cli(url)
          return content if content
        end

        raw_url = convert_to_raw_url(url)
        uri = URI(raw_url)
        response = Net::HTTP.get_response(uri)
        return response.body if response.code == '200'

        nil
      rescue StandardError
        nil
      end

      # Fetch file content from GitHub using gh CLI (tries API then clone).
      # @param url [String] GitHub blob URL
      # @return [String, nil] File content, or nil on failure
      def fetch_via_gh_cli(url)
        return nil unless url =~ %r{github\.com/([^/]+)/([^/]+)/blob/([^/]+)/(.+)}

        owner = Regexp.last_match(1)
        repo = Regexp.last_match(2)
        branch = Regexp.last_match(3)
        path = Regexp.last_match(4)

        content = fetch_via_gh_api(owner, repo, branch, path)
        return content if content

        fetch_via_gh_clone(owner, repo, branch, path)
      rescue StandardError => e
        puts "\u26a0\ufe0f  Error using gh CLI: #{e.message}"
        nil
      end

      # Fetch file content using GitHub REST API via gh CLI.
      # @param owner [String] Repository owner
      # @param repo [String] Repository name
      # @param branch [String] Branch name
      # @param path [String] File path within repository
      # @return [String, nil] Decoded file content, or nil on failure
      def fetch_via_gh_api(owner, repo, branch, path)
        result = `gh api repos/#{owner}/#{repo}/contents/#{path}?ref=#{branch} --jq .content 2>/dev/null`

        return nil unless $CHILD_STATUS.success? && !result.empty?

        Base64.decode64(result)
      end

      # Fetch file content by shallow-cloning the repository.
      # @param owner [String] Repository owner
      # @param repo [String] Repository name
      # @param branch [String] Branch name
      # @param path [String] File path within repository
      # @return [String, nil] File content, or nil on failure
      def fetch_via_gh_clone(owner, repo, branch, path)
        result = `gh repo view #{owner}/#{repo} --json defaultBranchRef --jq .defaultBranchRef.name 2>/dev/null`
        return nil unless $CHILD_STATUS.success? && !result.empty?

        default_branch = result.strip
        branch_to_use = %w[master main].include?(branch) ? default_branch : branch

        temp_dir = "/tmp/ruly_fetch_#{Process.pid}"
        clone_cmd = "gh repo clone #{owner}/#{repo} #{temp_dir} -- --depth=1 "
        clone_cmd += "--branch=#{branch_to_use} --single-branch 2>/dev/null"
        `#{clone_cmd}`

        return nil unless $CHILD_STATUS.success?

        file_path = File.join(temp_dir, path)
        content = File.exist?(file_path) ? File.read(file_path, encoding: 'UTF-8') : nil
        FileUtils.rm_rf(temp_dir)
        content
      end

      # Convert GitHub blob URLs to raw.githubusercontent.com URLs.
      # @param url [String] GitHub URL
      # @return [String] Raw content URL
      def convert_to_raw_url(url)
        if url.include?('github.com') && url.include?('/blob/')
          url.sub('github.com', 'raw.githubusercontent.com').sub('/blob/', '/')
        else
          url
        end
      end

      # Fetch markdown file paths from a GitHub directory via REST API.
      # @param owner [String] Repository owner
      # @param repo [String] Repository name
      # @param branch [String] Branch name
      # @param path [String] Directory path within repository
      # @return [Array<String>] List of file paths
      def fetch_github_markdown_files(owner, repo, branch, path)
        api_url = "https://api.github.com/repos/#{owner}/#{repo}/contents/#{path}?ref=#{branch}"
        puts "     DEBUG: Fetching #{api_url}" if ENV['DEBUG']

        begin
          response = fetch_url(api_url)
          unless response
            puts '     DEBUG: No response from API' if ENV['DEBUG']
            return []
          end

          files = []
          items = JSON.parse(response)
          puts "     DEBUG: Found #{items.length} items" if ENV['DEBUG']

          items.each do |item|
            if item['type'] == 'file' && item['path'].end_with?('.md', '.mdc')
              files << item['path']
            elsif item['type'] == 'dir'
              subdir_files = fetch_github_markdown_files(owner, repo, branch, item['path'])
              files.concat(subdir_files)
            end
          end

          files
        rescue StandardError => e
          puts "     \u26a0\ufe0f Error fetching GitHub files: #{e.message}" if ENV['DEBUG']
          []
        end
      end

      # Fetch content from a URL with appropriate headers.
      # @param url [String] URL to fetch
      # @return [String, nil] Response body, or nil on failure
      def fetch_url(url)
        uri = URI(url)
        request = Net::HTTP::Get.new(uri)
        request['Accept'] = 'application/vnd.github.v3+json' if url.include?('api.github.com')
        request['User-Agent'] = 'Ruly CLI'

        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
          http.request(request)
        end

        response.body if response.code == '200'
      rescue StandardError => e
        puts "     \u26a0\ufe0f Error fetching URL: #{e.message}" if ENV['DEBUG']
        nil
      end

      # Group remote sources by their GitHub repository (owner/repo).
      # @param remote_sources [Array<Hash>] Array of source hashes with :path keys
      # @return [Hash] Map of "owner/repo" to array of sources
      def group_remote_sources_by_repo(remote_sources)
        grouped = {}
        remote_sources.each do |source|
          next unless source[:path] =~ %r{https?://github\.com/([^/]+)/([^/]+)/}

          repo_key = "#{Regexp.last_match(1)}/#{Regexp.last_match(2)}"
          grouped[repo_key] ||= []
          grouped[repo_key] << source
        end
        grouped
      end

      # Batch prefetch remote files, using GraphQL for multi-file repositories.
      # @param sources [Array] Array of source specs (strings or hashes with :path and :type)
      # @param verbose [Boolean] Whether to show verbose output
      # @return [Hash] Map of source paths to prefetched content
      def prefetch_remote_files(sources, verbose: false)
        normalized_sources = sources.map do |s|
          if s.is_a?(String)
            {path: s, type: 'local'}
          else
            s
          end
        end

        remote_sources = normalized_sources.select { |s| s[:type] == 'remote' }
        return {} unless remote_sources.any?

        prefetched_content = {}
        grouped_remotes = group_remote_sources_by_repo(remote_sources)

        grouped_remotes.each do |repo_key, repo_sources|
          next unless repo_sources.size > 1

          puts "  \u{1F504} Batch fetching #{repo_sources.size} files from #{repo_key}..." if verbose
          batch_content = fetch_github_files_graphql(repo_key, repo_sources)
          if batch_content && !batch_content.empty?
            prefetched_content.merge!(batch_content)
            puts "    \u2705 Successfully fetched #{batch_content.size} files" if verbose
          else
            puts "    \u26a0\ufe0f Batch fetch failed, will fetch individually"
          end
        end

        prefetched_content
      end
    end
  end
end
