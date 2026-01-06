# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'

RSpec.describe Ruly::Checks::AmbiguousLinks do
  let(:test_dir) { Dir.mktmpdir }

  around do |example|
    original_dir = Dir.pwd

    begin
      Dir.chdir(test_dir)
      example.run
    ensure
      Dir.chdir(original_dir)
      FileUtils.rm_rf(test_dir) if test_dir && Dir.exist?(test_dir)
    end
  end

  describe '.call' do
    context 'when there are no ambiguous links' do
      it 'returns passed: true for sources with unique headers' do
        local_sources = [
          {
            content: "# File 1\n\n## Introduction\n\nWelcome to file 1.\n\n## Details\n\nSome details here.",
            path: 'rules/file1.md'
          },
          {
            content: "# File 2\n\n## Overview\n\nWelcome to file 2.\n\n## Configuration\n\nConfig details here.",
            path: 'rules/file2.md'
          }
        ]

        result = described_class.call(local_sources, [])
        expect(result[:passed]).to be(true)
        expect(result[:errors]).to be_empty
      end

      it 'returns passed: true when links reference unique anchors' do
        local_sources = [
          {
            content: "# File 1\n\nSee [Details](#details) for more info.\n\n## Details\n\nSome details here.",
            path: 'rules/file1.md'
          }
        ]

        result = described_class.call(local_sources, [])
        expect(result[:passed]).to be(true)
      end

      it 'returns passed: true for sources with no links' do
        local_sources = [
          {
            content: "# File 1\n\n## Overview\n\nJust some content without links.",
            path: 'rules/file1.md'
          }
        ]

        result = described_class.call(local_sources, [])
        expect(result[:passed]).to be(true)
      end

      it 'returns passed: true for empty sources' do
        result = described_class.call([], [])
        expect(result[:passed]).to be(true)
      end
    end

    context 'when there are ambiguous links' do
      it 'returns passed: false when a link references an anchor that exists in multiple files' do
        local_sources = [
          {
            content: "# File 1\n\nSee [Overview](#overview) for details.\n\n## Overview\n\nThis is overview in file 1.",
            path: 'rules/file1.md'
          },
          {
            content: "# File 2\n\n## Overview\n\nThis is overview in file 2.",
            path: 'rules/file2.md'
          }
        ]

        result = described_class.call(local_sources, [])
        expect(result[:passed]).to be(false)
        expect(result[:errors]).not_to be_empty
      end

      it 'returns passed: false when multiple links reference the same ambiguous anchor' do
        local_sources = [
          {
            content: "# File 1\n\nSee [Setup](#setup) and also [the setup section](#setup).\n\n" \
                     "## Setup\n\nSetup instructions for file 1.",
            path: 'rules/file1.md'
          },
          {
            content: "# File 2\n\n## Setup\n\nSetup instructions for file 2.",
            path: 'rules/file2.md'
          }
        ]

        result = described_class.call(local_sources, [])
        expect(result[:passed]).to be(false)
        expect(result[:errors].size).to eq(2)
      end

      it 'outputs a warning message for ambiguous links' do
        local_sources = [
          {
            content: "# File 1\n\nSee [Overview](#overview) for details.\n\n## Overview\n\nThis is overview in file 1.",
            path: 'rules/file1.md'
          },
          {
            content: "# File 2\n\n## Overview\n\nThis is overview in file 2.",
            path: 'rules/file2.md'
          }
        ]

        expect { described_class.call(local_sources, []) }
          .to output(/CRITICAL: Ambiguous markdown link references detected/).to_stdout
      end

      it 'includes the link text in the warning' do
        local_sources = [
          {
            content: "See [My Custom Link Text](#overview) for details.\n\n## Overview\n\nContent here.",
            path: 'rules/file1.md'
          },
          {
            content: "## Overview\n\nDifferent content.",
            path: 'rules/file2.md'
          }
        ]

        expect { described_class.call(local_sources, []) }
          .to output(/My Custom Link Text/).to_stdout
      end

      it 'includes the source file paths in the warning' do
        local_sources = [
          {
            content: "See [Overview](#overview) for details.\n\n## Overview\n\nContent.",
            path: 'rules/specific/path/file1.md'
          },
          {
            content: "## Overview\n\nDifferent content.",
            path: 'rules/other/path/file2.md'
          }
        ]

        output = capture_output { described_class.call(local_sources, []) }
        expect(output).to include('rules/specific/path/file1.md')
        expect(output).to include('rules/other/path/file2.md')
      end

      it 'includes line numbers in the warning' do
        local_sources = [
          {
            content: "# Header\n\nSee [Overview](#overview) for details.\n\n## Overview\n\nContent.",
            path: 'rules/file1.md'
          },
          {
            content: "## Overview\n\nDifferent content.",
            path: 'rules/file2.md'
          }
        ]

        output = capture_output { described_class.call(local_sources, []) }
        # The link is on line 3
        expect(output).to include(':3')
      end

      it 'does not output anything when check passes' do
        local_sources = [
          {
            content: "# File 1\n\n## Unique Section\n\nContent.",
            path: 'rules/file1.md'
          }
        ]

        expect { described_class.call(local_sources, []) }.not_to output.to_stdout
      end
    end
  end

  describe 'with command files' do
    it 'validates links in command files as well' do
      local_sources = [
        {
          content: "# File 1\n\n## Common Section\n\nContent here.",
          path: 'rules/file1.md'
        }
      ]

      command_files = [
        {
          content: "# Command\n\nSee [Common Section](#common-section) for details.\n\n" \
                   "## Common Section\n\nCommand-specific content.",
          path: 'rules/commands/cmd.md'
        }
      ]

      result = described_class.call(local_sources, command_files)
      expect(result[:passed]).to be(false)
    end

    it 'returns passed: true when command files have no conflicting anchors' do
      local_sources = [
        {
          content: "# File 1\n\n## Introduction\n\nContent here.",
          path: 'rules/file1.md'
        }
      ]

      command_files = [
        {
          content: "# Command\n\nSee [Usage](#usage) for details.\n\n## Usage\n\nHow to use this command.",
          path: 'rules/commands/cmd.md'
        }
      ]

      result = described_class.call(local_sources, command_files)
      expect(result[:passed]).to be(true)
    end
  end

  describe 'anchor generation edge cases' do
    it 'normalizes headers to lowercase for anchor matching' do
      local_sources = [
        {
          content: "See [overview](#overview) for details.\n\n## Overview\n\nContent.",
          path: 'rules/file1.md'
        },
        {
          content: "## OVERVIEW\n\nDifferent content.",
          path: 'rules/file2.md'
        }
      ]

      result = described_class.call(local_sources, [])
      expect(result[:passed]).to be(false)
    end

    it 'handles headers with special characters' do
      local_sources = [
        {
          content: "See [API Reference](#api-reference) for details.\n\n## API Reference!\n\nContent.",
          path: 'rules/file1.md'
        },
        {
          content: "## API Reference?\n\nDifferent content.",
          path: 'rules/file2.md'
        }
      ]

      # Both headers normalize to "api-reference" anchor
      result = described_class.call(local_sources, [])
      expect(result[:passed]).to be(false)
    end

    it 'handles headers with multiple spaces' do
      local_sources = [
        {
          content: "See [My Section](#my-section) for details.\n\n## My  Section\n\nContent.",
          path: 'rules/file1.md'
        },
        {
          content: "## My Section\n\nDifferent content.",
          path: 'rules/file2.md'
        }
      ]

      # Both headers normalize to "my-section" anchor
      result = described_class.call(local_sources, [])
      expect(result[:passed]).to be(false)
    end

    it 'handles links with encoded characters in anchor' do
      local_sources = [
        {
          content: "See [Setup Guide](#setup-guide) for details.\n\n## Setup Guide\n\nContent.",
          path: 'rules/file1.md'
        }
      ]

      result = described_class.call(local_sources, [])
      expect(result[:passed]).to be(true)
    end
  end

  describe 'duplicate headers without links' do
    it 'does not warn when duplicate headers exist but are not linked' do
      local_sources = [
        {
          content: "# File 1\n\n## Overview\n\nContent here.",
          path: 'rules/file1.md'
        },
        {
          content: "# File 2\n\n## Overview\n\nDifferent content.",
          path: 'rules/file2.md'
        }
      ]

      # No links to #overview, so no warning
      result = described_class.call(local_sources, [])
      expect(result[:passed]).to be(true)
    end
  end

  describe 'links to external URLs' do
    it 'ignores links that are not anchor references' do
      local_sources = [
        {
          content: "# File 1\n\nSee [Google](https://google.com) for search.\n" \
                   "See [Docs](./other-file.md) for docs.\n" \
                   "See [Overview](#overview) for local reference.\n\n## Overview\n\nContent.",
          path: 'rules/file1.md'
        }
      ]

      result = described_class.call(local_sources, [])
      expect(result[:passed]).to be(true)
    end
  end

  # Helper method to capture stdout
  def capture_output
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original_stdout
  end
end
