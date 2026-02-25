# frozen_string_literal: true

module Ruly
  module Services
    # Display and output formatting for CLI commands.
    # Contains all dry-run output, summary display, and profile listing logic
    # extracted from CLI command bodies.
    module Display # rubocop:disable Metrics/ModuleLength
      module_function

      # --- Squash dry-run display ---

      def squash_dry_run(local_sources, command_files, bin_files, skill_files, script_files, # rubocop:disable Metrics/ParameterLists
                         output_file, agent, profile_name, profile_config, options)
        puts "\n🔍 Dry run mode - no files will be created/modified\n\n"
        dry_run_clean_info(options)
        puts "Would create: #{output_file}"
        puts "  → #{local_sources.size} rule files combined"
        puts "  → Output size: ~#{local_sources.sum { |s| s[:content].size }} bytes"
        dry_run_commands(command_files, profile_config) if agent == 'claude' && !command_files.empty?
        dry_run_bins(bin_files) unless bin_files.empty?
        dry_run_skills(skill_files) if agent == 'claude' && !skill_files.empty?
        dry_run_scripts(script_files) if script_files[:local].any? || script_files[:remote].any?
        puts "\nWould cache output for profile '#{profile_name}'" if profile_name && options[:cache]
        dry_run_git_info(options)
        Services::SquashHelpers.copy_taskmaster_config(dry_run: true) if options[:taskmaster_config]
      end

      def dry_run_clean_info(options)
        if options[:deepclean]
          puts 'Would deep clean first:'
          %w[.claude/ CLAUDE.local.md CLAUDE.md].each { |f| puts "  → Remove #{f}" }
          puts '  → Remove .taskmaster/ directory' if options[:taskmaster_config]
          puts ''
        elsif options[:clean]
          puts 'Would clean existing files first'
          puts '  → Remove .taskmaster/ directory' if options[:taskmaster_config]
          puts ''
        end
      end

      def dry_run_commands(command_files, profile_config)
        puts "\nWould create command files in .claude/commands/:"
        omit_prefix = profile_config&.dig('omit_command_prefix')
        command_files.each do |file|
          puts "  → #{Services::ScriptManager.get_command_relative_path(file[:path], omit_prefix)}"
        end
      end

      def dry_run_bins(bin_files)
        puts "\nWould copy script files to .claude/scripts/:"
        bin_files.each { |f| puts "  → #{Services::SquashHelpers.calculate_bin_target(f[:relative_path])} (executable)" }
      end

      def dry_run_skills(skill_files)
        puts "\nWould create skill files in .claude/skills/:"
        skill_files.each do |file|
          puts "  → .claude/skills/#{Services::ScriptManager.derive_skill_name(file[:path])}/SKILL.md"
        end
      end

      def dry_run_scripts(script_files)
        total = script_files[:local].size + script_files[:remote].size
        puts "\nWould copy #{total} scripts to .claude/scripts/:"
        script_files[:local].each { |s| puts "  → #{s[:relative_path]} (local)" }
        script_files[:remote].each { |s| puts "  → #{s[:filename]} (remote from GitHub)" }
      end

      def dry_run_git_info(options)
        puts "\nWould update: .gitignore\n  → Add entries for generated files" if options[:git_ignore]
        puts "\nWould update: .git/info/exclude\n  → Add entries for generated files" if options[:git_exclude]
      end

      # --- Import dry-run display ---

      def import_dry_run(script_files, profile_name)
        puts "\n🔍 Dry run mode - no files will be copied\n\n"
        if script_files[:local].any? || script_files[:remote].any?
          total = script_files[:local].size + script_files[:remote].size
          puts "Would copy #{total} scripts to .claude/scripts/:"
          script_files[:local].each { |s| puts "  → #{s[:relative_path]} (local)" }
          script_files[:remote].each { |s| puts "  → #{s[:filename]} (remote from GitHub)" }
        else
          puts "No scripts found in profile '#{profile_name}'"
        end
      end

      # --- Squash summary ---

      def squash_summary(agent, profile_name, profile_config, output_file, cache_used, # rubocop:disable Metrics/ParameterLists
                         local_sources, command_files, skill_files)
        mode_desc = build_mode_description(agent, profile_name, profile_config, cache_used)
        total_files = if cache_used
                        Services::SquashHelpers.cached_file_count(output_file)
                      else
                        local_sources.size + command_files.size + skill_files.size
                      end

        Services::TOCGenerator.print_summary(mode_desc, output_file, total_files, agent:)
        if agent == 'claude' && command_files&.any?
          puts "📁 Saved #{command_files.size} command files to .claude/commands/ (with subdirectories)"
        end
        puts "🎯 Saved #{skill_files.size} skill files to .claude/skills/" if agent == 'claude' && skill_files&.any?
      end

      def build_mode_description(agent, profile_name, profile_config, cache_used)
        if agent == 'shell_gpt' then 'shell_gpt role JSON'
        elsif cache_used then "cached squash mode with '#{profile_name}' profile"
        elsif profile_name
          mode = profile_config.is_a?(Array) ? 'agent generation' : 'squash'
          "#{mode} mode with '#{profile_name}' profile"
        else
          'squash mode (combined content)'
        end
      end

      # --- Profile listing ---

      def profile_listing(name, config)
        puts "\n📦 #{name}"
        puts "   #{config['description']}" if config['description']
        puts

        all_files = collect_profile_display_files(config)

        if all_files.empty?
          puts '   (no files configured)'
        else
          tree = Services::ProfileIntrospector.build_profile_file_tree(all_files)
          Services::ProfileIntrospector.display_profile_tree(tree, '   ')
        end

        file_count = all_files.count { |f| !f.start_with?('http') }
        remote_count = all_files.count { |f| f.start_with?('http') }
        puts
        puts "   📊 Summary: #{file_count} local files" if file_count > 0
        puts "   🌐 Remote: #{remote_count} remote sources" if remote_count > 0
        puts "   🎯 Tier: #{config['tier'] || 'default'}" if config['tier']
      end

      def collect_profile_display_files(config)
        all_files = Array(config['files']).dup
        all_files.concat(Array(config['skills']))
        all_files.concat(Array(config['commands']))
        all_files.concat(Array(config['scripts']))
        config['sources']&.each do |source|
          if source.is_a?(Hash)
            if source['github']
              source['rules']&.each { |rule| all_files << "https://github.com/#{source['github']}/#{rule}" }
            elsif source['local']
              all_files.concat(source['local'])
            end
          else
            all_files << source
          end
        end
        all_files.concat(config['remote_sources']) if config['remote_sources']
        all_files
      end

      # --- Introspect summary ---

      def introspect_summary(profile_name, output_file, all_local_files, all_github_sources)
        total_files = all_local_files.length
        all_github_sources.each { |s| total_files += s[:rules].length }

        puts "\n✅ Profile '#{profile_name}' updated in #{output_file}"
        puts "   #{total_files} total files added to profile:"
        puts "   - #{all_local_files.length} local files" if all_local_files.any?
        return unless all_github_sources.any?

        puts "   - #{all_github_sources.sum { |s| s[:rules].length }} GitHub files"
      end

      # --- Init display ---

      def init_success(config_file)
        puts '🎉 Successfully initialized Ruly!'
        puts "\n📁 Created configuration at: #{config_file}"
        puts "\nNext steps:"
        puts "  1. Edit #{config_file} to add your rule sources"
        puts '  2. Uncomment and customize the example configurations'
        puts "  3. Run 'ruly squash starter' to combine your rules"
        puts "\nFor more information, see: https://github.com/patrickclery/ruly"
      end

      # --- Starter config YAML ---

      def starter_config_yaml
        <<~YAML
          # Ruly Configuration
          # Add your own profiles and rule sources here

          profiles:
            starter:
              description: "Basic starter profile - uncomment and customize the sources below"
          #{'    '}
              # Example: Add rules from GitHub repositories
              # sources:
              #   - github: patrickclery/rules
              #     branch: main
              #     rules:
              #       - ruby/common.md
              #       - testing/common.md
              ##{'   '}
              #   # Add rules from your own repository:
              #   - github: yourusername/your-rules
              #     branch: main
              #     rules:
              #       - path/to/your/rules.md
          #{'    '}
              # Example: Add local rule files
              # files:
              #   - /path/to/local/rules.md
              #   - ~/my-rules/ruby.md
        YAML
      end
    end
  end
end
