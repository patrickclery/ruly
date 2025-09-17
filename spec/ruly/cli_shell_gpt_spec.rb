# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'tempfile'

RSpec.describe Ruly::CLI do
  describe 'shell_gpt agent support' do
    let(:cli) { described_class.new }

    describe 'agent normalization' do
      it 'normalizes sgpt to shell_gpt' do
        cli.options = { agent: 'sgpt', output_file: 'role.json' }

        # We need to access the normalized agent value
        # This happens in the squash method, so we'll test it through behavior
        allow(cli).to receive(:collect_local_sources).and_return([])
        allow(cli).to receive(:process_sources_for_squash).and_return([[], [], []])
        allow(cli).to receive(:write_shell_gpt_json)
        allow(cli).to receive(:print_summary)

        cli.squash

        expect(cli).to have_received(:write_shell_gpt_json)
      end
    end

    describe '#write_shell_gpt_json' do
      let(:output_file) { 'test_role.json' }
      let(:local_sources) do
        [
          { path: 'rules/test1.md', content: 'Test content 1' },
          { path: 'rules/test2.md', content: 'Test content 2' }
        ]
      end

      after do
        File.delete(output_file) if File.exist?(output_file)
      end

      it 'creates a valid JSON file' do
        cli.send(:write_shell_gpt_json, output_file, local_sources)

        expect(File.exist?(output_file)).to be true

        content = File.read(output_file)
        json = JSON.parse(content)

        expect(json).to have_key('name')
        expect(json).to have_key('description')
      end

      it 'uses filename as role name' do
        cli.send(:write_shell_gpt_json, 'my_custom_role.json', local_sources)

        json = JSON.parse(File.read('my_custom_role.json'))
        expect(json['name']).to eq('my_custom_role')

        File.delete('my_custom_role.json')
      end

      it 'combines all source content in description' do
        cli.send(:write_shell_gpt_json, output_file, local_sources)

        json = JSON.parse(File.read(output_file, encoding: 'UTF-8'))
        description = json['description']

        expect(description).to include('rules/test1.md')
        expect(description).to include('Test content 1')
        expect(description).to include('rules/test2.md')
        expect(description).to include('Test content 2')
      end

      it 'properly escapes special characters in JSON' do
        sources_with_special = [
          {
            path: 'rules/special.md',
            content: 'Content with "quotes" and \\backslashes\\ and newlines\nand tabs\t'
          }
        ]

        cli.send(:write_shell_gpt_json, output_file, sources_with_special)

        # Should not raise JSON parse error
        json = JSON.parse(File.read(output_file, encoding: 'UTF-8'))

        # Check the content was preserved (after JSON escaping)
        expect(json['description']).to include('quotes')
        expect(json['description']).to include('backslashes')
        expect(json['description']).to include('newlines')
        expect(json['description']).to include('and tabs')
      end

      it 'handles invalid UTF-8 sequences' do
        invalid_content = "Valid text \xC3\x28 invalid UTF-8"
        sources_with_invalid = [
          { path: 'rules/invalid.md', content: invalid_content }
        ]

        # Should not raise an error
        expect {
          cli.send(:write_shell_gpt_json, output_file, sources_with_invalid)
        }.not_to raise_error

        json = JSON.parse(File.read(output_file, encoding: 'UTF-8'))
        expect(json['description']).to include('Valid text')
      end

      it 'handles markdown with code blocks' do
        markdown_content = <<~MD
          # Example

          ```ruby
          def hello
            puts "Hello, world!"
          end
          ```

          Use `backticks` for inline code.
        MD

        sources = [{ path: 'rules/code.md', content: markdown_content }]

        cli.send(:write_shell_gpt_json, output_file, sources)

        json = JSON.parse(File.read(output_file, encoding: 'UTF-8'))
        expect(json['description']).to include('```ruby')
        expect(json['description']).to include('def hello')
        expect(json['description']).to include('`backticks`')
      end
    end

    describe 'integration: squash with shell_gpt agent' do
      let(:temp_dir) { Dir.mktmpdir }
      let(:output_file) { File.join(temp_dir, 'role.json') }

      before do
        # Create test markdown files
        Dir.mkdir(File.join(temp_dir, 'rules'))

        File.write(File.join(temp_dir, 'rules', 'test1.md'), <<~MD)
          ---
          description: Test rule 1
          ---
          # Test Rule 1

          This is test content with "quotes" and special chars: $@#!
        MD

        File.write(File.join(temp_dir, 'rules', 'test2.md'), <<~MD)
          ---
          description: Test rule 2
          ---
          # Test Rule 2

          ```python
          def test():
              return "Hello"
          ```
        MD

        # Need to change directory for local source collection
        allow(Dir).to receive(:pwd).and_return(temp_dir)
        allow(Dir).to receive(:glob).with('rules/**/*.md').and_return([
          "rules/test1.md",
          "rules/test2.md"
        ])
      end

      after do
        FileUtils.rm_rf(temp_dir)
      end

      it 'generates JSON output for shell_gpt agent' do
        cli.options = {
          agent: 'shell_gpt',
          output_file: output_file,
          dry_run: false
        }

        # Mock file reading
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:read).and_call_original

        # Run squash
        cli.squash

        # Verify JSON was created
        expect(File.exist?(output_file)).to be true

        json = JSON.parse(File.read(output_file, encoding: 'UTF-8'))
        expect(json['name']).to eq('role')
        # Just check that description exists and is not empty
        expect(json['description']).to be_a(String)
        expect(json['description'].length).to be > 100
      end

      it 'skips metadata file creation for shell_gpt' do
        cli.options = {
          agent: 'shell_gpt',
          output_file: output_file,
          dry_run: false
        }

        cli.squash

        metadata_file = File.join(temp_dir, '.ruly.yml')
        expect(File.exist?(metadata_file)).to be false
      end

      it 'works with sgpt alias' do
        cli.options = {
          agent: 'sgpt',
          output_file: output_file,
          dry_run: false
        }

        cli.squash

        expect(File.exist?(output_file)).to be true
        json = JSON.parse(File.read(output_file, encoding: 'UTF-8'))
        expect(json).to have_key('name')
        expect(json).to have_key('description')
      end
    end

    describe 'summary output' do
      it 'shows appropriate message for shell_gpt agent' do
        cli.options = {
          agent: 'shell_gpt',
          output_file: 'test.json',
          dry_run: false
        }

        allow(cli).to receive(:collect_local_sources).and_return([])
        allow(cli).to receive(:process_sources_for_squash).and_return([[], [], []])
        allow(cli).to receive(:write_shell_gpt_json)

        expect(cli).to receive(:print_summary).with('shell_gpt role JSON', 'test.json', anything)

        cli.squash
      end
    end
  end
end