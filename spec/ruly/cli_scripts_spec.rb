# frozen_string_literal: true

require 'spec_helper'
require 'ruly/cli'
require 'tmpdir'
require 'fileutils'
require 'webmock/rspec'

RSpec.describe Ruly::CLI do
  let(:cli) { described_class.new }
  let(:temp_dir) { Dir.mktmpdir }

  before do
    WebMock.disable_net_connect!(allow_localhost: true)
  end

  after do
    FileUtils.rm_rf(temp_dir)
    WebMock.reset!
  end

  describe '#extract_scripts_from_frontmatter' do
    context 'with structured format' do
      it 'extracts files and remote scripts' do
        content = <<~YAML
          ---
          description: Test rule
          scripts:
            files:
              - scripts/setup.sh
              - scripts/database/migrate.sh
            remote:
              - github:org/repo/deploy.sh
              - https://github.com/org/repo/blob/main/monitor.sh
          ---
          # Test Content
        YAML

        result = cli.send(:extract_scripts_from_frontmatter, content, 'test.md')

        expect(result[:files]).to eq(['scripts/setup.sh', 'scripts/database/migrate.sh'])
        expect(result[:remote]).to eq([
          'github:org/repo/deploy.sh',
          'https://github.com/org/repo/blob/main/monitor.sh'
        ])
      end

      it 'handles missing files key' do
        content = <<~YAML
          ---
          description: Test rule
          scripts:
            remote:
              - github:org/repo/deploy.sh
          ---
          # Test Content
        YAML

        result = cli.send(:extract_scripts_from_frontmatter, content, 'test.md')

        expect(result[:files]).to eq([])
        expect(result[:remote]).to eq(['github:org/repo/deploy.sh'])
      end

      it 'handles missing remote key' do
        content = <<~YAML
          ---
          description: Test rule
          scripts:
            files:
              - scripts/setup.sh
          ---
          # Test Content
        YAML

        result = cli.send(:extract_scripts_from_frontmatter, content, 'test.md')

        expect(result[:files]).to eq(['scripts/setup.sh'])
        expect(result[:remote]).to eq([])
      end
    end

    context 'with simplified format (array)' do
      it 'treats array as files' do
        content = <<~YAML
          ---
          description: Test rule
          scripts:
            - scripts/setup.sh
            - scripts/database/migrate.sh
            - /abs/path/utils.sh
          ---
          # Test Content
        YAML

        result = cli.send(:extract_scripts_from_frontmatter, content, 'test.md')

        expect(result[:files]).to eq([
          'scripts/setup.sh',
          'scripts/database/migrate.sh',
          '/abs/path/utils.sh'
        ])
        expect(result[:remote]).to eq([])
      end
    end

    context 'with no frontmatter' do
      it 'returns empty arrays' do
        content = '# Test Content without frontmatter'

        result = cli.send(:extract_scripts_from_frontmatter, content, 'test.md')

        expect(result[:files]).to eq([])
        expect(result[:remote]).to eq([])
      end
    end

    context 'with no scripts key' do
      it 'returns empty arrays' do
        content = <<~YAML
          ---
          description: Test rule
          ---
          # Test Content
        YAML

        result = cli.send(:extract_scripts_from_frontmatter, content, 'test.md')

        expect(result[:files]).to eq([])
        expect(result[:remote]).to eq([])
      end
    end

    context 'with invalid YAML' do
      it 'returns empty arrays and warns' do
        content = <<~YAML
          ---
          scripts: [invalid yaml syntax
          ---
          # Test Content
        YAML

        expect do
          cli.send(:extract_scripts_from_frontmatter, content, 'test.md')
        end.to output(/Warning.*Failed to parse frontmatter/).to_stderr

        result = cli.send(:extract_scripts_from_frontmatter, content, 'test.md')
        expect(result[:files]).to eq([])
        expect(result[:remote]).to eq([])
      end
    end

    context 'with invalid scripts format' do
      it 'warns and returns empty arrays for string format' do
        content = <<~YAML
          ---
          description: Test rule
          scripts: "invalid-string-format"
          ---
          # Test Content
        YAML

        expect do
          cli.send(:extract_scripts_from_frontmatter, content, 'test.md')
        end.to output(/Warning.*Invalid scripts format/).to_stderr

        result = cli.send(:extract_scripts_from_frontmatter, content, 'test.md')
        expect(result[:files]).to eq([])
        expect(result[:remote]).to eq([])
      end

      it 'warns and returns empty arrays for number format' do
        content = <<~YAML
          ---
          description: Test rule
          scripts: 12345
          ---
          # Test Content
        YAML

        expect do
          cli.send(:extract_scripts_from_frontmatter, content, 'test.md')
        end.to output(/Warning.*Invalid scripts format/).to_stderr

        result = cli.send(:extract_scripts_from_frontmatter, content, 'test.md')
        expect(result[:files]).to eq([])
        expect(result[:remote]).to eq([])
      end
    end

    context 'with incomplete frontmatter' do
      it 'handles single frontmatter delimiter' do
        content = <<~YAML
          ---
          description: Test rule
          scripts:
            - scripts/setup.sh
          # Missing closing delimiter
        YAML

        result = cli.send(:extract_scripts_from_frontmatter, content, 'test.md')

        expect(result[:files]).to eq([])
        expect(result[:remote]).to eq([])
      end
    end
  end

  describe '#normalize_github_url' do
    context 'with shorthand format' do
      it 'converts github:org/repo/path to full URL' do
        url = 'github:myorg/myrepo/scripts/deploy.sh'

        result = cli.send(:normalize_github_url, url)

        expect(result).to eq('https://github.com/myorg/myrepo/scripts/deploy.sh')
      end

      it 'handles paths with subdirectories' do
        url = 'github:myorg/myrepo/scripts/database/migrate.sh'

        result = cli.send(:normalize_github_url, url)

        expect(result).to eq('https://github.com/myorg/myrepo/scripts/database/migrate.sh')
      end
    end

    context 'with full URL' do
      it 'returns URL unchanged' do
        url = 'https://github.com/myorg/myrepo/blob/main/scripts/deploy.sh'

        result = cli.send(:normalize_github_url, url)

        expect(result).to eq(url)
      end

      it 'handles raw.githubusercontent.com URLs' do
        url = 'https://raw.githubusercontent.com/myorg/myrepo/main/deploy.sh'

        result = cli.send(:normalize_github_url, url)

        expect(result).to eq(url)
      end
    end
  end

  describe '#collect_scripts_from_sources' do
    let(:rules_dir) { File.join(temp_dir, 'rules') }

    before do
      FileUtils.mkdir_p(File.join(rules_dir, 'scripts', 'database'))

      # Create test script files
      File.write(File.join(rules_dir, 'scripts', 'setup.sh'), '#!/bin/bash\necho "setup"')
      File.write(File.join(rules_dir, 'scripts', 'database', 'migrate.sh'), '#!/bin/bash\necho "migrate"')

      # Create test rule with scripts frontmatter
      rule_content = <<~YAML
        ---
        description: Test rule
        scripts:
          files:
            - scripts/setup.sh
            - scripts/database/migrate.sh
          remote:
            - github:org/repo/deploy.sh
        ---
        # Test Rule
      YAML
      File.write(File.join(rules_dir, 'test-rule.md'), rule_content)
    end

    it 'collects local script files from sources' do
      sources = [{path: 'rules/test-rule.md', type: 'local'}]

      # Mock find_rule_file to return our test files
      allow(cli).to receive(:find_rule_file).with('rules/test-rule.md')
        .and_return(File.join(rules_dir, 'test-rule.md'))
      allow(cli).to receive(:find_rule_file).with('scripts/setup.sh')
        .and_return(File.join(rules_dir, 'scripts', 'setup.sh'))
      allow(cli).to receive(:find_rule_file).with('scripts/database/migrate.sh')
        .and_return(File.join(rules_dir, 'scripts', 'database', 'migrate.sh'))

      result = cli.send(:collect_scripts_from_sources, sources)

      expect(result[:local].size).to eq(2)
      expect(result[:local][0][:relative_path]).to eq('setup.sh')
      expect(result[:local][1][:relative_path]).to eq('migrate.sh')
    end

    it 'collects remote script URLs from sources' do
      sources = [{path: 'rules/test-rule.md', type: 'local'}]

      allow(cli).to receive(:find_rule_file).with('rules/test-rule.md')
        .and_return(File.join(rules_dir, 'test-rule.md'))
      allow(cli).to receive(:find_rule_file).with('scripts/setup.sh')
        .and_return(File.join(rules_dir, 'scripts', 'setup.sh'))
      allow(cli).to receive(:find_rule_file).with('scripts/database/migrate.sh')
        .and_return(File.join(rules_dir, 'scripts', 'database', 'migrate.sh'))

      result = cli.send(:collect_scripts_from_sources, sources)

      expect(result[:remote].size).to eq(1)
      expect(result[:remote][0][:url]).to eq('https://github.com/org/repo/deploy.sh')
      expect(result[:remote][0][:filename]).to eq('deploy.sh')
    end

    it 'handles absolute paths' do
      abs_script_path = File.join(temp_dir, 'shared', 'utils.sh')
      FileUtils.mkdir_p(File.dirname(abs_script_path))
      File.write(abs_script_path, '#!/bin/bash\necho "utils"')

      rule_content = <<~YAML
        ---
        scripts:
          - #{abs_script_path}
        ---
        # Test Rule
      YAML
      File.write(File.join(rules_dir, 'abs-rule.md'), rule_content)

      sources = [{path: 'rules/abs-rule.md', type: 'local'}]

      allow(cli).to receive(:find_rule_file).with('rules/abs-rule.md')
        .and_return(File.join(rules_dir, 'abs-rule.md'))

      result = cli.send(:collect_scripts_from_sources, sources)

      expect(result[:local].size).to eq(1)
      expect(result[:local][0][:source_path]).to eq(abs_script_path)
    end

    it 'warns about missing script files' do
      rule_content = <<~YAML
        ---
        scripts:
          - scripts/missing.sh
        ---
        # Test Rule
      YAML
      File.write(File.join(rules_dir, 'missing-rule.md'), rule_content)

      sources = [{path: 'rules/missing-rule.md', type: 'local'}]

      allow(cli).to receive(:find_rule_file).with('rules/missing-rule.md')
        .and_return(File.join(rules_dir, 'missing-rule.md'))
      allow(cli).to receive(:find_rule_file).with('scripts/missing.sh')
        .and_return(nil)

      expect do
        cli.send(:collect_scripts_from_sources, sources)
      end.to output(/Warning.*Script not found/).to_stderr
    end

    it 'skips non-local sources' do
      sources = [
        {path: 'someuser/somerepo', type: 'github'}
      ]

      result = cli.send(:collect_scripts_from_sources, sources)

      expect(result[:local]).to be_empty
      expect(result[:remote]).to be_empty
    end
  end

  describe '#fetch_remote_scripts' do
    let(:remote_scripts) do
      [{
        filename: 'deploy.sh',
        from_rule: 'rules/test.md',
        url: 'https://github.com/org/repo/blob/main/deploy.sh'
      }]
    end

    context 'with successful fetch' do
      it 'downloads and returns script metadata' do
        script_content = "#!/bin/bash\necho 'deploy'"

        stub_request(:get, 'https://raw.githubusercontent.com/org/repo/main/deploy.sh')
          .to_return(body: script_content, status: 200)

        result = cli.send(:fetch_remote_scripts, remote_scripts)

        expect(result.size).to eq(1)
        expect(result[0][:filename]).to eq('deploy.sh')
        expect(result[0][:remote]).to be(true)
        expect(File.exist?(result[0][:source_path])).to be(true)
        expect(File.read(result[0][:source_path])).to eq(script_content)
      end

      it 'outputs success message' do
        stub_request(:get, 'https://raw.githubusercontent.com/org/repo/main/deploy.sh')
          .to_return(body: '#!/bin/bash', status: 200)

        expect do
          cli.send(:fetch_remote_scripts, remote_scripts)
        end.to output(/✓ deploy\.sh/).to_stdout
      end
    end

    context 'with HTTP errors' do
      it 'warns on 404 Not Found' do
        stub_request(:get, 'https://raw.githubusercontent.com/org/repo/main/deploy.sh')
          .to_return(body: 'Not Found', status: 404)

        expect do
          cli.send(:fetch_remote_scripts, remote_scripts)
        end.to output(/✗ Failed to fetch deploy\.sh: HTTP 404/).to_stderr

        result = cli.send(:fetch_remote_scripts, remote_scripts)
        expect(result).to be_empty
      end

      it 'warns on 401 Unauthorized' do
        stub_request(:get, 'https://raw.githubusercontent.com/org/repo/main/deploy.sh')
          .to_return(body: 'Unauthorized', status: 401)

        expect do
          cli.send(:fetch_remote_scripts, remote_scripts)
        end.to output(/✗ Failed to fetch deploy\.sh: HTTP 401/).to_stderr
      end
    end

    context 'with network errors' do
      it 'handles connection errors gracefully' do
        stub_request(:get, 'https://raw.githubusercontent.com/org/repo/main/deploy.sh')
          .to_raise(SocketError.new('Failed to open TCP connection'))

        expect do
          cli.send(:fetch_remote_scripts, remote_scripts)
        end.to output(/✗ Error fetching deploy\.sh/).to_stderr

        result = cli.send(:fetch_remote_scripts, remote_scripts)
        expect(result).to be_empty
      end

      it 'handles timeout errors' do
        stub_request(:get, 'https://raw.githubusercontent.com/org/repo/main/deploy.sh')
          .to_timeout

        expect do
          cli.send(:fetch_remote_scripts, remote_scripts)
        end.to output(/✗ Error fetching deploy\.sh/).to_stderr
      end
    end

    context 'with empty input' do
      it 'returns empty array without making requests' do
        result = cli.send(:fetch_remote_scripts, [])

        expect(result).to eq([])
      end
    end

    context 'with multiple scripts' do
      let(:multiple_scripts) do
        [
          {
            filename: 'deploy.sh',
            from_rule: 'rules/test.md',
            url: 'https://github.com/org/repo/blob/main/deploy.sh'
          },
          {
            filename: 'monitor.sh',
            from_rule: 'rules/test.md',
            url: 'https://github.com/org/repo/blob/main/monitor.sh'
          }
        ]
      end

      it 'fetches all scripts' do
        stub_request(:get, 'https://raw.githubusercontent.com/org/repo/main/deploy.sh')
          .to_return(body: '#!/bin/bash\necho "deploy"', status: 200)
        stub_request(:get, 'https://raw.githubusercontent.com/org/repo/main/monitor.sh')
          .to_return(body: '#!/bin/bash\necho "monitor"', status: 200)

        result = cli.send(:fetch_remote_scripts, multiple_scripts)

        expect(result.size).to eq(2)
        expect(result[0][:filename]).to eq('deploy.sh')
        expect(result[1][:filename]).to eq('monitor.sh')
      end

      it 'continues on partial failures' do
        stub_request(:get, 'https://raw.githubusercontent.com/org/repo/main/deploy.sh')
          .to_return(body: '#!/bin/bash\necho "deploy"', status: 200)
        stub_request(:get, 'https://raw.githubusercontent.com/org/repo/main/monitor.sh')
          .to_return(body: 'Not Found', status: 404)

        result = cli.send(:fetch_remote_scripts, multiple_scripts)

        expect(result.size).to eq(1)
        expect(result[0][:filename]).to eq('deploy.sh')
      end
    end
  end

  describe '#copy_scripts' do
    let(:scripts_dir) { File.join(temp_dir, '.claude', 'scripts') }
    let(:local_script_path) { File.join(temp_dir, 'setup.sh') }

    before do
      File.write(local_script_path, "#!/bin/bash\necho 'setup'")
    end

    context 'with local scripts only' do
      let(:script_files) do
        {
          local: [{
            from_rule: 'rules/test.md',
            relative_path: 'setup.sh',
            source_path: local_script_path
          }],
          remote: []
        }
      end

      it 'copies scripts to ~/.claude/scripts/' do
        cli.send(:copy_scripts, script_files, scripts_dir)

        expect(File.exist?(File.join(scripts_dir, 'setup.sh'))).to be(true)
      end

      it 'makes scripts executable' do
        cli.send(:copy_scripts, script_files, scripts_dir)

        script_path = File.join(scripts_dir, 'setup.sh')
        expect(File.executable?(script_path)).to be(true)
        expect(File.stat(script_path).mode & 0o777).to eq(0o755)
      end

      it 'outputs copy message' do
        expect do
          cli.send(:copy_scripts, script_files, scripts_dir)
        end.to output(/✓ setup\.sh \(local\).*🔧 Copied 1 scripts to/m).to_stdout
      end
    end

    context 'with subdirectories' do
      let(:db_script_path) { File.join(temp_dir, 'migrate.sh') }
      let(:script_files) do
        {
          local: [{
            from_rule: 'rules/test.md',
            relative_path: 'database/migrate.sh',
            source_path: db_script_path
          }],
          remote: []
        }
      end

      before do
        File.write(db_script_path, "#!/bin/bash\necho 'migrate'")
      end

      it 'preserves subdirectory structure' do
        cli.send(:copy_scripts, script_files, scripts_dir)

        expect(Dir.exist?(File.join(scripts_dir, 'database'))).to be(true)
        expect(File.exist?(File.join(scripts_dir, 'database', 'migrate.sh'))).to be(true)
      end
    end

    context 'with remote scripts' do
      it 'fetches and copies remote scripts' do
        remote_scripts = [{
          filename: 'deploy.sh',
          from_rule: 'rules/test.md',
          url: 'https://github.com/org/repo/blob/main/deploy.sh'
        }]

        script_files = {
          local: [],
          remote: remote_scripts
        }

        stub_request(:get, 'https://raw.githubusercontent.com/org/repo/main/deploy.sh')
          .to_return(body: "#!/bin/bash\necho 'deploy'", status: 200)

        cli.send(:copy_scripts, script_files, scripts_dir)

        expect(File.exist?(File.join(scripts_dir, 'deploy.sh'))).to be(true)
        expect(File.executable?(File.join(scripts_dir, 'deploy.sh'))).to be(true)
      end

      it 'outputs remote label for remote scripts' do
        remote_scripts = [{
          filename: 'deploy.sh',
          from_rule: 'rules/test.md',
          url: 'https://github.com/org/repo/blob/main/deploy.sh'
        }]

        script_files = {
          local: [],
          remote: remote_scripts
        }

        stub_request(:get, 'https://raw.githubusercontent.com/org/repo/main/deploy.sh')
          .to_return(body: '#!/bin/bash', status: 200)

        expect do
          cli.send(:copy_scripts, script_files, scripts_dir)
        end.to output(/✓ deploy\.sh \(remote\)/).to_stdout
      end
    end

    context 'with mixed local and remote scripts' do
      it 'copies both types correctly' do
        remote_scripts = [{
          filename: 'deploy.sh',
          from_rule: 'rules/test.md',
          url: 'https://github.com/org/repo/blob/main/deploy.sh'
        }]

        script_files = {
          local: [{
            from_rule: 'rules/test.md',
            relative_path: 'setup.sh',
            source_path: local_script_path
          }],
          remote: remote_scripts
        }

        stub_request(:get, 'https://raw.githubusercontent.com/org/repo/main/deploy.sh')
          .to_return(body: "#!/bin/bash\necho 'deploy'", status: 200)

        cli.send(:copy_scripts, script_files, scripts_dir)

        expect(File.exist?(File.join(scripts_dir, 'setup.sh'))).to be(true)
        expect(File.exist?(File.join(scripts_dir, 'deploy.sh'))).to be(true)
      end
    end

    context 'with empty input' do
      it 'does nothing with empty local and remote' do
        script_files = {local: [], remote: []}

        expect do
          cli.send(:copy_scripts, script_files, scripts_dir)
        end.not_to output.to_stdout

        expect(Dir.exist?(scripts_dir)).to be(false)
      end
    end

    context 'with default destination' do
      it 'uses .claude/scripts/ in current working directory as default' do
        script_files = {
          local: [{
            from_rule: 'rules/test.md',
            relative_path: 'setup.sh',
            source_path: local_script_path
          }],
          remote: []
        }

        # Change to temp dir to test default behavior
        Dir.chdir(temp_dir) do
          cli.send(:copy_scripts, script_files)

          default_scripts_dir = File.join(temp_dir, '.claude', 'scripts')
          expect(File.exist?(File.join(default_scripts_dir, 'setup.sh'))).to be(true)
        end
      end
    end
  end
end
