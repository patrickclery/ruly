# frozen_string_literal: true

require 'bundler/setup'
require 'ruly'
require 'tmpdir'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Never read or write the real ~/.config/ruly/remotes mirror from specs: a synced
  # mirror on the developer machine would otherwise win the recipe lookup chain.
  config.around do |example|
    Dir.mktmpdir('ruly-spec-remotes') do |dir|
      @ruly_spec_remotes_dir = dir
      example.run
    end
  end

  config.before do
    allow(Ruly::Services::RemoteSync).to receive(:remotes_dir).and_return(@ruly_spec_remotes_dir)
  end
end
