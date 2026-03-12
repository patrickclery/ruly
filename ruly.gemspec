# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = 'ruly'
  spec.version       = '0.1.0'
  spec.authors       = ['Patrick Clery']
  spec.email         = ['patrick@example.com']

  spec.summary       = 'A Ruby gem for managing AI assistant configuration rules'
  spec.description   = 'Ruly provides a centralized system for managing and distributing AI coding assistant ' \
                       'rules and configurations across projects, with recipe-based compilation and easy integration.'
  spec.homepage      = 'https://github.com/patrickclery/ruly'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.3.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['rubygems_mfa_required'] = 'true'

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.glob(%w[
    lib/**/*
    rules/**/*.md
    recipes.yml
    bin/*
    LICENSE.txt
    README.md
    CHANGELOG.md
    ]).select do |f|
    File.file?(f)
  end

  spec.bindir        = 'bin'
  spec.executables   = ['ruly']
  spec.require_paths = ['lib']

  # Runtime dependencies
  spec.add_dependency 'thor', '~> 1.2'
  spec.add_dependency 'tiktoken_ruby', '~> 0.0.9'

  # Development dependencies are in Gemfile
end
