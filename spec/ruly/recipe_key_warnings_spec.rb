# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ruly::Services::RecipeLoader, '.recipe_key_warnings' do
  it 'returns nothing for a recipe using only known keys' do
    recipe = {'files' => [], 'model' => 'haiku', 'omit_command_prefix' => ['x']}
    expect(described_class.recipe_key_warnings('demo', recipe)).to eq([])
  end

  it 'returns nothing for an Array agent recipe' do
    expect(described_class.recipe_key_warnings('demo', ['a.md'])).to eq([])
  end

  it 'flags a removed key with the release that removed it' do
    warnings = described_class.recipe_key_warnings('demo', {'tier' => 'claude_max'})
    expect(warnings.size).to eq(1)
    expect(warnings.first).to include("Recipe 'demo': 'tier' was removed in ruly 0.2.0 and is ignored")
  end

  it 'flags an unknown key' do
    warnings = described_class.recipe_key_warnings('core-debugger', {'omitCommandPrefix' => 'workaxle'})
    expect(warnings.size).to eq(1)
    expect(warnings.first).to include("unknown key 'omitCommandPrefix' is ignored")
  end

  it 'never includes key values in the messages' do
    warnings = described_class.recipe_key_warnings('demo', {'omitCommandPrefix' => 'workaxle', 'tier' => 'claude_max'})
    expect(warnings.size).to eq(2)
    expect(warnings.join("\n")).not_to include('claude_max', 'workaxle')
  end
end

RSpec.describe Ruly::CLI, '#load_sources recipe key warnings' do
  let(:cli) { described_class.new }
  let(:recipe) { {'description' => 'Demo', 'files' => [], 'tier' => 'claude_max'} }

  before do
    allow(cli).to receive(:load_all_recipes).and_return({'demo' => recipe})
    allow(Ruly::Services::RecipeLoader).to receive(:load_recipe_sources).and_return([[], recipe])
  end

  it 'warns once per recipe on stderr and keeps loading' do
    expect do
      2.times { expect(cli.send(:load_sources, 'demo')).to eq([[], recipe]) }
    end.to output(
      satisfy { |err| err.scan("Recipe 'demo': 'tier' was removed in ruly 0.2.0").size == 1 }
    ).to_stderr
  end

  it 'does not echo key values' do
    expect { cli.send(:load_sources, 'demo') }.not_to output(/claude_max/).to_stderr
  end
end
