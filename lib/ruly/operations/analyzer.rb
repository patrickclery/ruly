# frozen_string_literal: true

require 'tiktoken_ruby'
require 'yaml'

module Ruly
  module Operations
    # Analyze token usage for recipes
    class Analyzer < Base
      attr_reader :recipe_name, :recipes_file, :gem_root, :plan_override, :contexts

      # Format and display stats result from Operations::Stats
      # @param result [Hash] Result hash from Operations::Stats#call
      def self.display_stats_result(result)
        if result[:success]
          data = result[:data]
          formatted_tokens = format_number(data[:total_tokens])
          puts "✅ Generated #{data[:output_file]}"
          puts "   #{data[:file_count]} files, #{formatted_tokens} tokens total"
          if data[:orphaned_count].positive?
            puts "   ⚠️  #{data[:orphaned_count]} orphaned files (not used by any recipe)"
          end
        else
          puts "❌ Error: #{result[:error]}"
          exit 1
        end
      end

      # Format a number with comma separators
      # @param num [Integer] Number to format
      # @return [String] Formatted number string
      def self.format_number(num)
        num.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\\1,')
      end

      # @param recipe_name [String, nil] Name of recipe to analyze (nil for all)
      # @param recipes_file [String] Path to recipes.yml
      # @param gem_root [String] Root path of the gem
      # @param plan_override [String, nil] Override pricing plan (from CLI --plan option)
      # @param analyze_all [Boolean] Whether to analyze all recipes
      def initialize(gem_root:, recipes_file:, analyze_all: false, plan_override: nil, recipe_name: nil)
        super()
        @recipe_name = recipe_name
        @recipes_file = recipes_file
        @gem_root = gem_root
        @plan_override = plan_override
        @analyze_all = analyze_all
        @contexts = load_contexts
      end

      def call
        if @analyze_all
          analyze_all_recipes
        elsif recipe_name
          analyze_single_recipe(recipe_name)
        else
          build_result(error: 'Recipe required', success: false)
        end
      rescue StandardError => e
        build_result(error: e.message, success: false)
      end

      private

      def load_contexts
        contexts_file = File.join(gem_root, 'lib', 'ruly', 'contexts.yml')
        if File.exist?(contexts_file)
          YAML.load_file(contexts_file)
        else
          {}
        end
      end

      def analyze_all_recipes
        recipes = Services::RecipeLoader.load_all_recipes(base_recipes_file: recipes_file, gem_root:)

        puts '📊 Token Analysis for All Recipes'
        puts '=' * 60

        recipes.each_key do |name|
          sources, = load_recipe_sources_for(name, recipes)

          # Calculate content size
          total_content = ''
          file_count = 0

          sources.each do |source|
            if source[:type] == 'local'
              file_path = Services::RecipeLoader.find_rule_file(source[:path], gem_root:)
              if file_path
                content = File.read(file_path, encoding: 'UTF-8')
                total_content += content
                file_count += 1
              end
            elsif source[:type] == 'remote'
              total_content += ' ' * 2000 # Estimate
              file_count += 1
            end
          end

          token_count = count_tokens(total_content)
          plan = get_plan_for_recipe(name)
          context_limit = get_context_limit_for_plan(plan)

          display_recipe_analysis(name, file_count, token_count, plan, context_limit, compact: true)
        rescue StandardError => e
          puts "  ❌ #{name}: Error - #{e.message}"
        end

        build_result(data: {recipe_count: recipes.size}, success: true)
      end

      def load_recipe_sources_for(name, recipes = nil)
        recipes ||= Services::RecipeLoader.load_all_recipes(base_recipes_file: recipes_file, gem_root:)
        recipe = Services::RecipeLoader.validate_recipe!(name, recipes)

        sources = []
        Services::RecipeLoader.process_recipe_files(recipe, sources, gem_root:)
        Services::RecipeLoader.process_recipe_sources(recipe, sources, gem_root:)
        Services::RecipeLoader.process_legacy_remote_sources(recipe, sources)

        [sources, recipe]
      end

      def count_tokens(text)
        encoder = Tiktoken.get_encoding('cl100k_base')
        utf8_text = text.encode('UTF-8', invalid: :replace, replace: '?', undef: :replace)
        encoder.encode(utf8_text).length
      end

      def get_plan_for_recipe(name)
        # Priority: CLI option > recipe-level > user config > global default
        return plan_override if plan_override

        # Load recipe config
        recipes = Services::RecipeLoader.load_all_recipes(base_recipes_file: recipes_file, gem_root:)
        recipe = recipes[name]
        return recipe['plan'] if recipe.is_a?(Hash) && recipe['plan']

        # Check user config
        user_config_file = File.expand_path('~/.config/ruly/recipes.yml')
        if File.exist?(user_config_file)
          user_config = YAML.safe_load_file(user_config_file, aliases: true) || {}
          return user_config['plan'] if user_config['plan']
        end

        # Check global default in recipes.yml
        recipes_config = YAML.safe_load_file(recipes_file, aliases: true) || {}
        return recipes_config['plan'] if recipes_config['plan']

        # Default fallback
        'claude_pro'
      end

      def get_context_limit_for_plan(plan)
        # Handle aliases
        plan = contexts['aliases'][plan] if contexts.dig('aliases', plan)

        # Parse nested plan (e.g., "claude.pro")
        if plan.include?('.')
          service, tier = plan.split('.', 2)
          context_info = contexts.dig(service, tier)
        else
          # Search all services for the plan
          contexts.each_value do |tiers|
            next unless tiers.is_a?(Hash)

            tiers.each_value do |info|
              next unless info.is_a?(Hash)
              return info['context'] if info['name'] == plan
            end
          end
        end

        context_info ? context_info['context'] : 100_000 # Default fallback
      end

      def display_recipe_analysis(name, file_count, token_count, plan, context_limit, compact: false)
        percentage = ((token_count.to_f / context_limit) * 100).round(1)

        # Format numbers
        formatted_tokens = self.class.format_number(token_count)
        formatted_limit = self.class.format_number(context_limit)

        # Status indicator
        status = status_indicator(percentage)

        if compact
          context_label = formatted_limit
          puts format('  %-20<recipe>s %6<tokens>s tokens / %-7<context>s (%5.1<percent>f%%) %<status>s [%<plan>s]',
                      context: context_label,
                      percent: percentage,
                      plan:,
                      recipe: name,
                      status:,
                      tokens: formatted_tokens)
        else
          puts "\n📦 Recipe: #{name}"
          puts "📄 Files: #{file_count}"
          puts "🎯 Plan: #{plan}"
          puts "🧮 Tokens: #{formatted_tokens} / #{formatted_limit} (#{percentage}%) #{status}"

          display_context_warning(percentage)
        end
      end

      def status_indicator(percentage)
        if percentage < 50
          '🟢'
        elsif percentage < 80
          '🟡'
        elsif percentage < 95
          '🟠'
        else
          '🔴'
        end
      end

      def display_context_warning(percentage, indent: '')
        if percentage > 80
          puts "#{indent}⚠️  Warning: This recipe is approaching the context limit!" if percentage < 95
          puts "#{indent}❌ Error: This recipe exceeds the context limit!" if percentage >= 100
        else
          puts "#{indent}✅ This recipe fits comfortably within your plan's context window"
        end
      end

      def analyze_single_recipe(name)
        sources, = load_recipe_sources_for(name)

        # Calculate content and tokens for each file
        file_details = []
        total_content = ''
        file_count = 0

        sources.each do |source|
          total_content, file_count = process_source_for_analysis(source, file_details, total_content, file_count)
        end

        # Get token count
        token_count = count_tokens(total_content)

        # Get plan and context limit
        plan = get_plan_for_recipe(name)
        context_limit = get_context_limit_for_plan(plan)

        # Display detailed analysis
        display_detailed_analysis(name, file_details, token_count, plan, context_limit)

        build_result(
          data: {
            context_limit:,
            file_count:,
            file_details:,
            plan:,
            recipe_name: name,
            token_count:
          },
          success: true
        )
      end

      def process_source_for_analysis(source, file_details, total_content, file_count)
        if source[:type] == 'local'
          file_path = Services::RecipeLoader.find_rule_file(source[:path], gem_root:)
          if file_path
            content = File.read(file_path, encoding: 'UTF-8')
            tokens = count_tokens(content)
            file_details << {
              path: source[:path],
              size: content.bytesize,
              tokens:,
              type: 'local'
            }
            total_content += content
            file_count += 1
          end
        elsif source[:type] == 'remote'
          # For dry-run, estimate remote file size
          estimated_content = ' ' * 2000 # Estimate 2KB per remote file
          tokens = count_tokens(estimated_content)
          file_details << {
            path: source[:path],
            size: 2000,
            tokens:,
            type: 'remote'
          }
          total_content += estimated_content
          file_count += 1
        end
        [total_content, file_count]
      end

      def display_detailed_analysis(name, file_details, token_count, plan, context_limit)
        percentage = ((token_count.to_f / context_limit) * 100).round(1)
        formatted_tokens = self.class.format_number(token_count)
        formatted_limit = self.class.format_number(context_limit)

        # Status indicator
        status = status_indicator(percentage)

        puts "\n📦 Recipe: #{name}"
        puts "🎯 Plan: #{plan}"
        puts

        # Build file tree structure
        tree = build_file_tree(file_details)
        display_file_tree(tree)

        puts
        puts '📊 Total Summary:'
        puts "   Files: #{file_details.size}"
        puts "   Tokens: #{formatted_tokens} / #{formatted_limit} (#{percentage}%) #{status}"

        display_context_warning(percentage, indent: '   ')
      end

      def build_file_tree(file_details)
        tree = {}

        file_details.each do |file|
          path_parts = file[:path].split('/')
          current_level = tree

          path_parts.each_with_index do |part, index|
            if index == path_parts.length - 1
              # This is a file
              current_level[part] = file
            else
              # This is a directory
              current_level[part] ||= {}
              current_level = current_level[part]
            end
          end
        end

        tree
      end

      def display_file_tree(tree, is_root: true, prefix: '')
        items = tree.to_a
        ctx = {is_root:, item_count: items.length, prefix:}

        items.each_with_index do |(key, value), index|
          ctx[:is_last_item] = index == items.length - 1

          if value.is_a?(Hash) && value[:path]
            display_file_leaf(key, value, ctx)
          elsif value.is_a?(Hash)
            display_directory_node(key, value, ctx)
          end
        end
      end

      def display_file_leaf(key, value, ctx)
        tokens = self.class.format_number(value[:tokens])
        size_kb = (value[:size] / 1024.0).round(1)
        type_icon = value[:type] == 'remote' ? '🌐' : '📄'

        if ctx[:is_root] && ctx[:item_count] == 1
          puts "#{type_icon} #{key} (#{tokens} tokens, #{size_kb} KB)"
        else
          connector = ctx[:is_last_item] ? '└── ' : '├── '
          puts "#{ctx[:prefix]}#{connector}#{type_icon} #{key} (#{tokens} tokens, #{size_kb} KB)"
        end
      end

      def display_directory_node(key, value, ctx)
        if ctx[:is_root] && ctx[:item_count] == 1
          puts "📁 #{key}/"
          display_file_tree(value, is_root: false, prefix: '')
        else
          connector = ctx[:is_last_item] ? '└── ' : '├── '
          puts "#{ctx[:prefix]}#{connector}📁 #{key}/"

          new_prefix = ctx[:prefix] + (ctx[:is_last_item] ? '    ' : '│   ')
          display_file_tree(value, is_root: false, prefix: new_prefix)
        end
      end
    end
  end
end
