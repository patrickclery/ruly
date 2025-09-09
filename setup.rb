#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'open3'

# Try to use Thor if available, otherwise use a simple implementation
begin
  require 'thor'
  THOR_AVAILABLE = true
rescue LoadError
  THOR_AVAILABLE = false
end

# Colors for output
class Colors
  RED = "\033[0;31m"
  GREEN = "\033[0;32m"
  YELLOW = "\033[1;33m"
  NC = "\033[0m" # No Color

  def self.red(text) = "#{RED}#{text}#{NC}"
  def self.green(text) = "#{GREEN}#{text}#{NC}"
  def self.yellow(text) = "#{YELLOW}#{text}#{NC}"
end

if THOR_AVAILABLE
  # Thor-based installer
  class RulyInstaller < Thor
    include Thor::Actions

    INSTALL_DIR = File.expand_path('~/ruly')
    REPO_URL = 'https://github.com/patrickclery/ruly.git'
    REPO_BRANCH = ENV['RULY_BRANCH'] || 'main' # Default to main branch

    def self.source_root
      File.dirname(__FILE__)
    end

    def self.exit_on_failure?
      true
    end

    default_task :install

    desc 'install', 'Install Ruly to ~/ruly'
    option :force, default: false, desc: 'Force reinstall even if already installed', type: :boolean
    option :path, default: INSTALL_DIR, desc: 'Installation directory', type: :string
    def install
      @install_dir = options[:path]

      say "🚀 Installing Ruly to #{@install_dir}", :cyan
      say

      check_ruby_version
      check_bundler
      remove_old_installation if options[:force] || !Dir.exist?(@install_dir)
      clone_repository unless Dir.exist?(@install_dir)
      install_dependencies
      create_executable
      update_shell_path
      initialize_config

      print_success_message
    rescue StandardError => e
      say Colors.red("❌ Installation failed: #{e.message}")
      exit 1
    end

    desc 'uninstall', 'Remove Ruly installation'
    def uninstall
      if Dir.exist?(INSTALL_DIR)
        if yes?("Remove Ruly from #{INSTALL_DIR}? (y/N)")
          remove_file INSTALL_DIR
          say Colors.green('✅ Ruly has been uninstalled')
          say Colors.yellow('Remember to remove PATH export from your shell configuration')
        else
          say 'Uninstall cancelled'
        end
      else
        say Colors.yellow("Ruly is not installed at #{INSTALL_DIR}")
      end
    end

    desc 'update', 'Update Ruly to the latest version'
    def update
      unless Dir.exist?(INSTALL_DIR)
        say Colors.red("❌ Ruly is not installed. Run 'ruby setup.rb' first")
        exit 1
      end

      inside INSTALL_DIR do
        say '📥 Updating Ruly...', :cyan
        run 'git pull --quiet', capture: true
        run 'bundle install --quiet', capture: true
        say Colors.green('✅ Ruly has been updated to the latest version')
      end
    end

    private

    def check_ruby_version
      required_version = '3.0.0'
      current_version = RUBY_VERSION

      if Gem::Version.new(current_version) < Gem::Version.new(required_version)
        say Colors.red("❌ Ruby #{required_version} or higher is required. You have #{current_version}")
        exit 1
      end

      say Colors.green("✅ Ruby #{current_version} detected")
    end

    def check_bundler
      unless system('which bundle > /dev/null 2>&1')
        say Colors.yellow('📦 Installing bundler...')
        run 'gem install bundler', capture: true
      end
      say Colors.green('✅ Bundler is installed')
    end

    def remove_old_installation
      return unless Dir.exist?(@install_dir)

      say Colors.yellow('🗑️  Removing old installation...')
      remove_file @install_dir
    end

    def clone_repository
      say '📥 Downloading Ruly...', :cyan
      run "git clone --quiet --branch '#{REPO_BRANCH}' '#{REPO_URL}' '#{@install_dir}'", capture: true
    end

    def install_dependencies
      say '📦 Installing dependencies...', :cyan
      inside @install_dir do
        run 'bundle config set --local path "vendor/bundle"', capture: true
        run 'bundle config set --local without "development test"', capture: true
        run 'bundle install --quiet', capture: true
      end
    end

    def create_executable
      create_file "#{@install_dir}/bin/ruly", <<~RUBY, force: true
        #!/usr/bin/env ruby
        # frozen_string_literal: true

        # Standalone Ruly executable
        ENV['BUNDLE_GEMFILE'] = File.expand_path('../../Gemfile', __FILE__)

        require 'bundler/setup'
        require_relative '../lib/ruly'

        # Set RULY_HOME for standalone mode
        ENV['RULY_HOME'] = File.expand_path('../..', __FILE__)

        Ruly::CLI.start(ARGV)
      RUBY

      chmod "#{@install_dir}/bin/ruly", 0o755
    end

    def update_shell_path
      shell_config = detect_shell_config
      path_line = 'export PATH="$HOME/ruly/bin:$PATH"'

      if shell_config && File.exist?(shell_config)
        config_content = File.read(shell_config)
        if config_content.include?(path_line)
          say Colors.green("✅ PATH already configured in #{shell_config}")
          @shell_config = shell_config
          return
        end
      end

      # Don't modify shell config, just show instructions
      say
      say Colors.yellow('⚠️  Please add Ruly to your PATH')
      say
      if shell_config
        say "Add the following line to #{shell_config}:"
        say
        say Colors.green("   #{path_line}")
        say
        say 'Then run:'
        say Colors.green("   source #{shell_config}")
      else
        say 'Add the following to your shell configuration file:'
        say
        say Colors.green("   #{path_line}")
      end
      say
      say 'Or start a new terminal session for changes to take effect.'

      @shell_config = shell_config
    end

    def detect_shell_config
      shell = ENV['SHELL'] || ''

      if shell.include?('zsh')
        File.expand_path('~/.zshrc')
      elsif shell.include?('bash')
        detect_bash_config
      elsif shell.include?('fish')
        File.expand_path('~/.config/fish/config.fish')
      else
        detect_shell_config_fallback
      end
    end

    def detect_bash_config
      if File.exist?(File.expand_path('~/.bash_profile'))
        File.expand_path('~/.bash_profile')
      else
        File.expand_path('~/.bashrc')
      end
    end

    def detect_shell_config_fallback
      if File.exist?(File.expand_path('~/.zshrc'))
        File.expand_path('~/.zshrc')
      elsif File.exist?(File.expand_path('~/.bash_profile'))
        File.expand_path('~/.bash_profile')
      elsif File.exist?(File.expand_path('~/.bashrc'))
        File.expand_path('~/.bashrc')
      end
    end

    def initialize_config
      say
      say '📁 Setting up configuration...', :cyan
      run "#{@install_dir}/bin/ruly init 2>/dev/null", capture: true
    end

    def print_success_message
      say
      say Colors.green('🎉 Ruly has been successfully installed!')
      say
      say 'Next steps:', :yellow
      say "  1. Reload your shell: source #{@shell_config}" if @shell_config
      say "  2. Run 'ruly help' to see available commands"
      say '  3. Edit ~/.config/ruly/recipes.yml to add your rule sources'
      say
      say 'To uninstall Ruly, run:', :cyan
      say '  rm -rf ~/ruly'
      say "  # Then remove the PATH export from #{@shell_config}" if @shell_config
    end
  end
else
  # Fallback simple installer when Thor is not available
  class SimpleRulyInstaller
    INSTALL_DIR = File.expand_path('~/ruly')
    REPO_URL = 'https://github.com/patrickclery/ruly.git'
    REPO_BRANCH = ENV['RULY_BRANCH'] || 'main' # Default to main branch

    def run
      puts "🚀 Installing Ruly to #{INSTALL_DIR}"
      puts
      note = 'Note: Installing without Thor gem. For better experience, '
      note += 'install Thor first: gem install thor'
      puts Colors.yellow(note)
      puts

      check_ruby_version
      check_bundler
      remove_old_installation
      clone_repository
      install_dependencies
      create_executable
      update_shell_path
      initialize_config

      print_success_message
    rescue StandardError => e
      puts Colors.red("❌ Installation failed: #{e.message}")
      exit 1
    end

    private

    def check_ruby_version
      required_version = '3.0.0'
      current_version = RUBY_VERSION

      if Gem::Version.new(current_version) < Gem::Version.new(required_version)
        puts Colors.red("❌ Ruby #{required_version} or higher is required. You have #{current_version}")
        exit 1
      end

      puts Colors.green("✅ Ruby #{current_version} detected")
    end

    def check_bundler
      unless system('which bundle > /dev/null 2>&1')
        puts Colors.yellow('📦 Installing bundler...')
        system('gem install bundler') or raise 'Failed to install bundler'
      end
      puts Colors.green('✅ Bundler is installed')
    end

    def remove_old_installation
      return unless Dir.exist?(INSTALL_DIR)

      puts Colors.yellow('🗑️  Removing old installation...')
      FileUtils.rm_rf(INSTALL_DIR)
    end

    def clone_repository
      puts '📥 Downloading Ruly...'
      branch = ENV['RULY_BRANCH'] || 'main'
      cmd = "git clone --quiet --branch '#{branch}' '#{REPO_URL}' '#{INSTALL_DIR}'"
      system(cmd) or raise 'Failed to clone repository'
    end

    def install_dependencies
      puts '📦 Installing dependencies...'
      Dir.chdir(INSTALL_DIR) do
        system('bundle config set --local path "vendor/bundle"', out: File::NULL) or raise 'Failed to configure bundler'
        system('bundle config set --local without "development test"',
               out: File::NULL) or raise 'Failed to configure bundler'
        system('bundle install --quiet') or raise 'Failed to install dependencies'
      end
    end

    def create_executable
      FileUtils.mkdir_p("#{INSTALL_DIR}/bin")

      executable_content = <<~RUBY
        #!/usr/bin/env ruby
        # frozen_string_literal: true

        # Standalone Ruly executable
        ENV['BUNDLE_GEMFILE'] = File.expand_path('../../Gemfile', __FILE__)

        require 'bundler/setup'
        require_relative '../lib/ruly'

        # Set RULY_HOME for standalone mode
        ENV['RULY_HOME'] = File.expand_path('../..', __FILE__)

        Ruly::CLI.start(ARGV)
      RUBY

      File.write("#{INSTALL_DIR}/bin/ruly", executable_content)
      File.chmod(0o755, "#{INSTALL_DIR}/bin/ruly")
    end

    def update_shell_path
      shell_config = detect_shell_config
      path_line = 'export PATH="$HOME/ruly/bin:$PATH"'

      if shell_config && File.exist?(shell_config)
        handle_existing_config(shell_config, path_line)
      elsif shell_config
        create_shell_config(shell_config, path_line)
      else
        print_manual_instructions
      end

      @shell_config = shell_config
    end

    def detect_shell_config
      shell = ENV['SHELL'] || ''

      if shell.include?('zsh')
        File.expand_path('~/.zshrc')
      elsif shell.include?('bash')
        detect_bash_config
      elsif shell.include?('fish')
        File.expand_path('~/.config/fish/config.fish')
      else
        detect_shell_config_fallback
      end
    end

    def detect_bash_config
      if File.exist?(File.expand_path('~/.bash_profile'))
        File.expand_path('~/.bash_profile')
      else
        File.expand_path('~/.bashrc')
      end
    end

    def detect_shell_config_fallback
      if File.exist?(File.expand_path('~/.zshrc'))
        File.expand_path('~/.zshrc')
      elsif File.exist?(File.expand_path('~/.bash_profile'))
        File.expand_path('~/.bash_profile')
      elsif File.exist?(File.expand_path('~/.bashrc'))
        File.expand_path('~/.bashrc')
      end
    end

    def handle_existing_config(shell_config, path_line)
      config_content = File.read(shell_config)

      if config_content.include?(path_line)
        puts Colors.green("✅ PATH already configured in #{shell_config}")
      else
        append_to_shell_config(shell_config, path_line)
      end
    end

    def append_to_shell_config(shell_config, path_line)
      File.open(shell_config, 'a') do |f|
        f.puts
        f.puts '# Ruly - AI assistant rules manager'
        f.puts path_line
      end
      puts Colors.green("✅ Added #{INSTALL_DIR}/bin to PATH in #{shell_config}")
      msg = "   Run 'source #{shell_config}' or start a new terminal to use ruly"
      puts Colors.yellow(msg)
    end

    def create_shell_config(shell_config, path_line)
      File.open(shell_config, 'w') do |f|
        f.puts '# Ruly - AI assistant rules manager'
        f.puts path_line
      end
      puts Colors.green("✅ Created #{shell_config} and added PATH")
    end

    def print_manual_instructions
      puts Colors.yellow('⚠️  Could not detect shell configuration file')
      puts Colors.yellow('   Please add the following to your shell configuration:')
      puts
      puts '   export PATH="$HOME/ruly/bin:$PATH"'
      puts
    end

    def initialize_config
      puts
      puts '📁 Setting up configuration...'
      system("#{INSTALL_DIR}/bin/ruly init 2>/dev/null") || true
    end

    def print_success_message
      puts
      puts Colors.green('🎉 Ruly has been successfully installed!')
      puts
      puts 'Next steps:'
      puts "  1. Reload your shell: source #{@shell_config}" if @shell_config
      puts "  2. Run 'ruly help' to see available commands"
      puts '  3. Edit ~/.config/ruly/recipes.yml to add your rule sources'
      puts
      puts 'To uninstall Ruly, run:'
      puts '  rm -rf ~/ruly'
      puts "  # Then remove the PATH export from #{@shell_config}" if @shell_config
    end
  end
end

# Run the installer if this script is executed directly
if __FILE__ == $PROGRAM_NAME
  if THOR_AVAILABLE
    RulyInstaller.start(ARGV)
  else
    SimpleRulyInstaller.new.run
  end
end
