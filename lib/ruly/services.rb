# frozen_string_literal: true

require_relative 'services/dependency_resolver'
require_relative 'services/display'
require_relative 'services/frontmatter_parser'
require_relative 'services/git_ignore_manager'
require_relative 'services/github_client'
require_relative 'services/mcp_manager'
require_relative 'services/recipe_introspector'
require_relative 'services/recipe_loader'
require_relative 'services/script_manager'
require_relative 'services/shell_command_checker'
require_relative 'services/source_processor'
require_relative 'services/squash_helpers'
require_relative 'services/subagent_processor'
require_relative 'services/toc_generator'

module Ruly
  # Extracted service modules from the main CLI class
  module Services
  end
end
