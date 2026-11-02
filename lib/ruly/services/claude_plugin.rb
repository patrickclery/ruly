# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'yaml'

module Ruly
  module Services
    # Claude Code plugin output target (`ruly squash RECIPE -a claude-plugin`).
    # Writes a plugin directory (default `ruly-plugin-RECIPE/`) holding
    # `.claude-plugin/plugin.json` and the recipe's squashed rules as the skill
    # `skills/RECIPE-rules/SKILL.md`. Claude Code plugins cannot carry always-on
    # instructions, so the rules ship as a skill and a notice says so. Nothing is
    # written into the project (`.claude/`, CLAUDE.local.md, `.mcp.json`).
    #
    # The manifest's `metadata.generator: ruly` marks the directory as ruly-owned:
    # only an owned directory is ever wiped by squash or removed by clean.
    module ClaudePlugin # rubocop:disable Metrics/ModuleLength
      module_function

      AGENT = 'claude-plugin'
      GENERATOR = 'ruly'
      MANIFEST = File.join('.claude-plugin', 'plugin.json')
      CLAUDE_DEFAULT_OUTPUT = 'CLAUDE.local.md'
      DIR_PREFIX = 'ruly-plugin-'
      NAME_PATTERN = /\A[A-Za-z0-9][A-Za-z0-9._-]*\z/
      RESERVED_NAMES = %w[anthropic anthropics claude claude-code claude-mods].freeze
      RESERVED_PREFIXES = %w[anthropic- anthropics- cc-plugin- claude-].freeze
      DESCRIPTION_LIMIT = 1536
      COMPONENT_DIRS = %w[skills commands agents].freeze
      SECRET_KEYS = %w[env headers].freeze
      PLUGIN_SCRIPTS = '${CLAUDE_PLUGIN_ROOT}/scripts'
      # `.claude/scripts/X` not preceded by a word character, '/', '.' or '~' (so `~/.claude/...`
      # and `$HOME/.claude/...` stay put); X ends in a word character (no trailing sentence dot).
      SCRIPT_REF = %r{(?<![\w/.~])\.claude/scripts/([\w./-]*\w)}
      # SCRIPT_REF absorbing one pair of double quotes around the reference (hook commands).
      QUOTED_SCRIPT_REF = %r{(?<![\w/.~])("?)\.claude/scripts/([\w./-]*\w)\1}

      # Resolve the plugin directory.
      # @param requested [String, nil] the -o value (Thor default 'CLAUDE.local.md')
      # @param recipe_name [String] recipe name
      # @return [String] `ruly-plugin-NAME` unless -o was explicit; else requested without a trailing '/'
      def output_dir(requested, recipe_name)
        return "#{DIR_PREFIX}#{recipe_name}" if requested.nil? || requested == CLAUDE_DEFAULT_OUTPUT

        stripped = requested.sub(%r{/+\z}, '')
        stripped.empty? ? requested : stripped
      end

      # Validate the recipe the plugin is built from.
      # @param recipe_name [String, nil] recipe name
      # @param recipe_config [Hash, Array, nil] recipe configuration
      # @raise [Ruly::Error] no recipe, an Array recipe, or a name unsafe or reserved for a plugin
      def validate_recipe!(recipe_name, recipe_config)
        raise Ruly::Error, '-a claude-plugin needs a recipe: ruly squash RECIPE -a claude-plugin' unless recipe_name

        if recipe_config.is_a?(Array)
          raise Ruly::Error, "-a claude-plugin needs a Hash recipe; '#{recipe_name}' is an agent (Array) recipe"
        end

        unless safe_name?(recipe_name)
          raise Ruly::Error, "Recipe name '#{recipe_name}' is not a valid plugin name " \
                             "(letters, digits, '.', '_' and '-'; no '..')"
        end
        return unless reserved?(recipe_name)

        raise Ruly::Error, "Recipe name '#{recipe_name}' is reserved by Claude Code for plugins"
      end

      # @param recipe_name [String] recipe name
      # @return [Boolean] whether Claude Code reserves the name for its own plugins
      def reserved?(recipe_name)
        name = recipe_name.downcase
        RESERVED_NAMES.include?(name) || RESERVED_PREFIXES.any? { |prefix| name.start_with?(prefix) }
      end

      # Validate the recipe and resolve and guard the plugin directory. Writes nothing.
      # @return [String] the plugin directory
      # @raise [Ruly::Error] see validate_recipe! and guard_dir!
      def prepare!(requested, recipe_name, recipe_config)
        validate_recipe!(recipe_name, recipe_config)
        dir = output_dir(requested, recipe_name)
        guard_dir!(dir)
        dir
      end

      # Whether ruly generated the directory: its manifest parses to a Hash whose
      # metadata.generator is 'ruly'. Reads only the manifest.
      # @param dir [String] plugin directory
      # @return [Boolean]
      def generated?(dir)
        path = File.join(dir, MANIFEST)
        return false unless File.file?(path)

        data = JSON.parse(File.read(path, encoding: 'UTF-8'))
        data.is_a?(Hash) && data['metadata'].is_a?(Hash) && data['metadata']['generator'] == GENERATOR
      rescue JSON::ParserError, SystemCallError
        false
      end

      # Refuse a directory ruly must not wipe or write into.
      # @param dir [String] plugin directory
      # @raise [Ruly::Error] the working directory, a parent of it, $HOME or '/'; an existing
      #   non-directory; a non-empty directory ruly did not generate
      def guard_dir!(dir)
        reason = refusal_reason(dir)
        raise Ruly::Error, "Refusing to use #{dir} as the plugin directory: #{reason}" if reason
        raise Ruly::Error, "#{dir} exists and is not a directory" if File.exist?(dir) && !File.directory?(dir)
        return unless File.directory?(dir) && !Dir.empty?(dir) && !generated?(dir)

        raise Ruly::Error, "#{dir} exists and was not generated by ruly (no ruly metadata in " \
                           '.claude-plugin/plugin.json). Move it aside or pass -o DIR.'
      end

      # Why DIR must never be used (or cleaned) as the plugin directory.
      # @param dir [String] plugin directory
      # @return [String, nil] the reason, nil when DIR may be used
      def refusal_reason(dir)
        # ruly never expands '~' (the filesystem calls would use the literal path), so refuse it.
        return "a leading '~' is not expanded by ruly; pass the path unquoted or spell it out" if dir.start_with?('~')
        return unless dangerous?(dir)

        'it is the working directory, one of its parents or your home directory'
      end

      # Compares physical paths (symlinks resolved, '//' collapsed), so a symlinked path to the
      # working directory or $HOME is caught. A path that does not exist cannot be any of them.
      # @param dir [String] plugin directory
      # @return [Boolean] whether DIR is the working directory, one of its parents, $HOME or '/'
      def dangerous?(dir)
        path = physical_path(dir)
        return false unless path

        cwd = File.realpath(Dir.pwd)
        ['/', cwd, physical_path(Dir.home)].include?(path) || cwd.start_with?("#{path}/")
      rescue SystemCallError, ArgumentError
        true # cannot resolve the working or home directory: refuse rather than risk wiping it
      end

      # @param path [String] a path
      # @return [String, nil] the physical path of an existing PATH, nil when it does not exist
      def physical_path(path)
        File.realpath(path)
      rescue Errno::ENOENT, Errno::ENOTDIR
        nil
      end

      # Empty the plugin directory and write the ownership marker at once, so a run that
      # fails later leaves a directory ruly still owns (re-runnable, cleanable).
      # @param dir [String] plugin directory
      def reset_dir(dir)
        guard_dir!(dir)
        FileUtils.rm_rf(dir) if generated?(dir)
        FileUtils.mkdir_p(File.join(dir, File.dirname(MANIFEST)))
        File.write(File.join(dir, MANIFEST), "#{JSON.pretty_generate({'metadata' => {'generator' => GENERATOR}})}\n")
      end

      # @return [String, nil] `git config user.name`, nil when unset or git is missing
      def git_author
        name = IO.popen(%w[git config user.name], err: File::NULL, &:read).to_s.strip
        name.empty? ? nil : name
      rescue SystemCallError
        nil
      end

      # Plugin manifest: name, version, description, author, metadata (in that order).
      # @param recipe_name [String] recipe name (the plugin name)
      # @param recipe_config [Hash] recipe configuration
      # @param author [String, nil] author name
      # @return [Hash]
      def manifest(recipe_name, recipe_config, author:)
        data = {'name' => recipe_name, 'version' => Ruly::VERSION}
        description = recipe_description(recipe_config)
        data['description'] = description if description
        data['author'] = {'name' => author} if author
        data['metadata'] = {'generator' => GENERATOR, 'recipe' => recipe_name}
        data
      end

      # @return [String, nil] the recipe's non-empty description
      def recipe_description(recipe_config)
        description = recipe_config.is_a?(Hash) ? recipe_config['description'] : nil
        description.is_a?(String) && !description.strip.empty? ? description.strip : nil
      end

      # @param recipe_name [String] recipe name
      # @return [String] name of the skill carrying the squashed rules
      def rules_skill_name(recipe_name) = "#{recipe_name}-rules"

      # Refuse skill and command paths that would clobber the rules skill or leave the plugin dir.
      # Runs before any of those files is written.
      # @param dir [String] plugin directory
      # @param command_files [Array<Hash, String>] recipe commands
      # @param recipe_config [Hash] recipe configuration (omit_command_prefix)
      # @param recipe_name [String] recipe name
      # @param skill_files [Array<Hash>] recipe skills
      # @raise [Ruly::Error] a skill named RECIPE-rules, an unsafe skill name (see check_skill_names!),
      #   or a command whose target is not under DIR/commands/
      def check_paths!(dir, command_files:, recipe_config:, recipe_name:, skill_files:)
        check_skill_names!(skill_files, recipe_name)
        commands_root = File.expand_path(File.join(dir, 'commands'))
        omit_prefix = recipe_config.is_a?(Hash) ? recipe_config['omit_command_prefix'] : nil
        command_files.each do |file|
          path = file.is_a?(Hash) ? file[:path] : file
          relative = ScriptManager.get_command_relative_path(path, omit_prefix)
          next if File.expand_path(relative, commands_root).start_with?("#{commands_root}/")

          raise Ruly::Error, "Command path '#{path}' escapes #{dir}/commands"
        end
      end

      # Check skill names before the skills are written. Recipe skills are checked by check_paths!;
      # each subagent's skills are checked with CLAIMED holding the skills already in the plugin.
      # @param skill_files [Array<Hash>] skills about to be written
      # @param recipe_name [String] recipe name
      # @param claimed [Hash] flat skill name => source path of the skills already in the plugin;
      #   updated with SKILL_FILES
      # @return [Hash] claimed
      # @raise [Ruly::Error] a name that is not a safe plugin name (NAME_PATTERN, no '..') or that
      #   is the generated RECIPE-rules skill; warns when a name is taken by another source file
      def check_skill_names!(skill_files, recipe_name, claimed = {})
        skill_files.each do |file|
          name = ScriptManager.flat_skill_name(file[:path])
          unless safe_name?(name)
            raise Ruly::Error, "Skill path '#{file[:path]}' maps to an unsafe plugin skill name '#{name}'"
          end

          if name == rules_skill_name(recipe_name)
            raise Ruly::Error, "Skill '#{file[:path]}' collides with the generated rules skill #{name}"
          end

          if claimed.key?(name) && claimed[name] != file[:path]
            warn "\u26A0\uFE0F  Skills #{claimed[name]} and #{file[:path]} both map to plugin skill '#{name}'; " \
                 'the last one wins'
          end
          claimed[name] = file[:path]
        end
        claimed
      end

      # @param skill_files [Array<Hash>] skills already written into the plugin
      # @return [Hash] flat skill name => source path, for check_skill_names!
      def skill_claims(skill_files)
        skill_files.to_h { |file| [ScriptManager.flat_skill_name(file[:path]), file[:path]] }
      end

      # @param name [String] a plugin, skill or agent name
      # @return [Boolean] whether NAME is a single safe path segment (NAME_PATTERN, no '..')
      def safe_name?(name) = name.match?(NAME_PATTERN) && !name.include?('..')

      # Write the plugin: manifest, rules skill and commands. Never writes a CLAUDE.md, a
      # SessionStart hook or an output style (plugins cannot carry always-on instructions),
      # and never adds component keys to plugin.json (the default directory scan stays in effect).
      # @param dir [String] plugin directory (already reset)
      # @param command_files [Array<Hash, String>] recipe commands
      # @param gem_root [String, nil] gem root (import-mode command paths)
      # @param local_sources [Array<Hash>] processed rule sources
      # @param recipe_config [Hash] recipe configuration
      # @param recipe_name [String] recipe name
      # @param script_mappings [Hash] absolute script path => relative name
      # @param script_files [Hash] frontmatter scripts `{local: [...], remote: [...]}`, copied to DIR/scripts
      # @param skill_files [Array<Hash>] recipe skills (checked here, written by the caller)
      # @param toc [Boolean] whether to write a table of contents
      def write(dir, command_files:, gem_root:, local_sources:, recipe_config:, recipe_name:, script_files:,
                script_mappings:, skill_files:, toc:)
        check_paths!(dir, command_files:, recipe_config:, recipe_name:, skill_files:)
        FileUtils.mkdir_p(File.join(dir, File.dirname(MANIFEST)))
        File.write(File.join(dir, MANIFEST),
                   "#{JSON.pretty_generate(manifest(recipe_name, recipe_config, author: git_author))}\n")
        write_rules_skill(dir, local_sources:, recipe_config:, recipe_name:, script_mappings:, toc:)
        unless command_files.empty?
          ScriptManager.save_command_files(command_files, recipe_config, commands_dir: File.join(dir, 'commands'),
                                                                         gem_root:)
        end
        if Array(script_files[:local]).any? || Array(script_files[:remote]).any?
          ScriptManager.copy_scripts(script_files, File.join(dir, 'scripts'))
        end
        write_hooks(dir, recipe_config)
        write_mcp(dir, Array(recipe_config['mcp_servers']))
      end

      # Write `DIR/hooks/hooks.json`: the recipe `hooks:` under a top-level `hooks` key, each
      # `command` passed through hook_command. Writes nothing when hooks is not a non-empty Hash.
      # @param dir [String] plugin directory
      # @param recipe_config [Hash] recipe configuration
      def write_hooks(dir, recipe_config)
        hooks = recipe_config.is_a?(Hash) ? recipe_config['hooks'] : nil
        return unless hooks.is_a?(Hash) && !hooks.empty?

        FileUtils.mkdir_p(File.join(dir, 'hooks'))
        File.write(File.join(dir, 'hooks', 'hooks.json'),
                   "#{JSON.pretty_generate({'hooks' => rewrite_hook_commands(hooks, dir)})}\n")
      end

      # @return [Object] a copy of value with every String under a 'command' key passed through hook_command
      def rewrite_hook_commands(value, dir)
        case value
        when Hash
          value.to_h do |key, item|
            [key, key == 'command' && item.is_a?(String) ? hook_command(item, dir) : rewrite_hook_commands(item, dir)]
          end
        when Array then value.map { |item| rewrite_hook_commands(item, dir) }
        else value
        end
      end

      # Rewrite `.claude/scripts/X` in a hook command to the double-quoted
      # `"${CLAUDE_PLUGIN_ROOT}/scripts/X"` when X was copied into DIR/scripts; other references
      # are kept and named on stderr.
      # @param command [String] hook command
      # @param dir [String] plugin directory
      # @return [String]
      def hook_command(command, dir)
        command.gsub(QUOTED_SCRIPT_REF) do
          match = Regexp.last_match
          next %("#{PLUGIN_SCRIPTS}/#{match[2]}") if copied_script?(dir, match[2])

          warn "\u26A0\uFE0F  Hook command references .claude/scripts/#{match[2]}, which is not a recipe script; " \
               'left unchanged'
          match[0]
        end
      end

      # @return [Boolean] whether DIR/scripts holds the script (no '..' segments)
      def copied_script?(dir, script)
        !script.split('/').include?('..') && File.file?(File.join(dir, 'scripts', script))
      end

      # Write `DIR/.mcp.json` from `~/.config/ruly/mcp.json` and name (never print) literal secrets.
      # Writes nothing when no server resolves.
      # @param dir [String] plugin directory
      # @param server_names [Array<String>] MCP server names
      def write_mcp(dir, server_names)
        servers = MCPManager.load_mcp_servers_from_config(server_names)
        return unless servers.is_a?(Hash) && !servers.empty?

        FileUtils.mkdir_p(dir)
        File.write(File.join(dir, '.mcp.json'), "#{JSON.pretty_generate({'mcpServers' => servers})}\n")
        names = literal_secret_servers(servers)
        return if names.empty?

        warn "\u26A0\uFE0F  #{dir}/.mcp.json has literal env/headers values for: #{names.join(', ')}. " \
             'Replace them with ${VAR} references before sharing the plugin.'
      end

      # @param servers [Hash] name => server config
      # @return [Array<String>] sorted names whose env or headers Hash holds a non-empty String without '${'
      def literal_secret_servers(servers)
        servers.select do |_name, config|
          config.is_a?(Hash) && SECRET_KEYS.any? do |key|
            config[key].is_a?(Hash) && config[key].values.any? do |value|
              value.is_a?(String) && !value.empty? && !value.include?('${')
            end
          end
        end.keys.sort
      end

      # Rewrite `.claude/scripts/X` to `${CLAUDE_PLUGIN_ROOT}/scripts/X` in the markdown under
      # DIR/skills, DIR/commands and DIR/agents, for every X copied into DIR/scripts. Other
      # references are left alone (a script may be installed some other way).
      # @param dir [String] plugin directory
      def rewrite_script_paths(dir)
        scripts_root = File.join(dir, 'scripts')
        copied = Dir.glob('**/*', base: scripts_root).select { |path| File.file?(File.join(scripts_root, path)) }
        return if copied.empty?

        COMPONENT_DIRS.flat_map { |sub| Dir.glob(File.join(dir, sub, '**', '*.md')) }.each do |file|
          text = File.read(file, encoding: 'UTF-8')
          updated = text.gsub(SCRIPT_REF) do
            match = Regexp.last_match
            copied.include?(match[1]) ? "#{PLUGIN_SCRIPTS}/#{match[1]}" : match[0]
          end
          File.write(file, updated) unless updated == text
        end
      end

      # Recipe parts a plugin cannot carry, by key only.
      # @param recipe_config [Hash] recipe configuration
      # @return [Array<String>] subset of 'model', 'isolate', 'subagent permissionMode', 'subagent cwd hooks'
      def skipped_parts(recipe_config)
        return [] unless recipe_config.is_a?(Hash)

        subagents = recipe_config['subagents'].is_a?(Array) ? recipe_config['subagents'] : []
        parts = []
        parts << 'model' if recipe_config['model'].is_a?(String) && !recipe_config['model'].empty?
        parts << 'isolate' if recipe_config['isolate'] == true
        parts << 'subagent permissionMode' unless subagents.empty?
        parts << 'subagent cwd hooks' if subagents.any? { |agent| agent.is_a?(Hash) && agent['append'] && agent['cwd'] }
        parts
      end

      # Write `skills/NAME-rules/SKILL.md`: name/description frontmatter, then the squashed body.
      def write_rules_skill(dir, local_sources:, recipe_config:, recipe_name:, script_mappings:, toc:)
        skill_dir = File.join(dir, 'skills', rules_skill_name(recipe_name))
        FileUtils.mkdir_p(skill_dir)
        File.open(File.join(skill_dir, 'SKILL.md'), 'w') do |io|
          io.puts '---'
          io.write rules_skill_frontmatter(recipe_name, recipe_config)
          io.puts '---'
          if toc
            io.puts Services::TOCGenerator.generate_toc_content(local_sources, [], AGENT)
            io.puts
          end
          Services::SquashHelpers.write_sources(io, local_sources, script_mappings, toc:)
        end
      end

      # @return [String] YAML for the rules skill frontmatter, without the leading '---' line
      def rules_skill_frontmatter(recipe_name, recipe_config)
        frontmatter = {'name' => rules_skill_name(recipe_name)}
        frontmatter['description'] = rules_skill_description(recipe_name, recipe_config)
        YAML.dump(frontmatter).sub(/\A---\s*\n/, '')
      end

      # @return [String] description telling Claude when to load the rules skill (max 1,536 chars)
      def rules_skill_description(recipe_name, recipe_config)
        description = recipe_description(recipe_config)
        source = description ? "'#{recipe_name}' (#{description})" : "'#{recipe_name}'"
        "Rules from the ruly recipe #{source}. Invoke before starting any task in this project."[0, DESCRIPTION_LIMIT]
      end

      # Stdout lines printed on every -a claude-plugin run (dry run included): the always-on
      # notice, plus the skipped-parts notice when skipped_parts is non-empty.
      # @param recipe_name [String] recipe name
      # @param recipe_config [Hash] recipe configuration
      # @return [Array<String>]
      def notices(recipe_name, recipe_config)
        lines = ["\u2139\uFE0F  Claude Code plugins cannot carry always-on instructions, so the rules were written " \
                 "as skill /#{recipe_name}:#{rules_skill_name(recipe_name)}. For always-on rules run " \
                 "`ruly squash #{recipe_name}` (CLAUDE.local.md)."]
        parts = skipped_parts(recipe_config)
        lines << "\u2139\uFE0F  claude-plugin target skips: #{parts.join(', ')}" unless parts.empty?
        lines
      end

      # What `clean -a claude-plugin` may remove: the plugin dir, and only when ruly generated it.
      # Never lists the project's .claude/, .mcp.json, .mcp.yml or CLAUDE.local.md.
      # @param requested [String, nil] the -o value (`squash --clean` passes the Thor default)
      # @param recipe_name [String, nil] recipe name
      # @return [Array<String>] ['DIR/'] or []; a skipped dir is explained on stderr
      def files_to_clean(requested, recipe_name)
        if recipe_name.nil? && (requested.nil? || requested == CLAUDE_DEFAULT_OUTPUT)
          warn "\u26A0\uFE0F  clean -a claude-plugin: pass RECIPE or -o DIR"
          return []
        end
        dir = output_dir(requested, recipe_name)
        reason = refusal_reason(dir)
        if reason
          warn "\u26A0\uFE0F  Refusing to clean #{dir}: #{reason}"
          return []
        end
        return ["#{dir}/"] if generated?(dir)

        if File.exist?(dir)
          warn "\u26A0\uFE0F  Skipping #{dir}: not generated by ruly (no ruly metadata in #{MANIFEST})"
        end
        []
      end
    end
  end
end
