# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'

RSpec.describe Ruly::CLI, '.start -a claude-plugin' do
  let(:test_dir) { Dir.mktmpdir }
  let(:fixture_dir) { File.expand_path('../fixtures/claude_plugin', __dir__) }
  let(:plugin_dir) { 'ruly-plugin-demo' }
  let(:manifest_path) { File.join(plugin_dir, '.claude-plugin', 'plugin.json') }
  let(:rules_skill_path) { File.join(plugin_dir, 'skills', 'demo-rules', 'SKILL.md') }

  around do |example|
    original_dir = Dir.pwd
    begin
      Dir.chdir(test_dir)
      example.run
    ensure
      # CRITICAL: Always return to original directory before ANY cleanup
      Dir.chdir(original_dir)
      FileUtils.rm_rf(test_dir) if test_dir && Dir.exist?(test_dir)
    end
  end

  before do
    FileUtils.cp_r(File.join(fixture_dir, '.'), test_dir)
    allow(Ruly::Services::RecipeLoader).to receive(:user_recipes_file)
      .and_return(File.join(test_dir, 'no-user-recipes.yml'))
    allow(Ruly::Services::ClaudePlugin).to receive(:git_author).and_return('Fixture Author')
    allow(Ruly::Services::MCPManager).to receive(:load_mcp_servers_from_config).and_return(nil)
  end

  def read_utf8(path) = File.read(path, encoding: 'UTF-8')

  def run_cli(*args)
    expect { described_class.start(args) }.to output.to_stdout
  end

  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end

  def expect_refusal(args, stderr)
    expect do
      expect { described_class.start(args) }.to raise_error(SystemExit) { |e| expect(e.status).to eq(1) }
    end.to output(stderr).to_stderr
  end

  # Every path under DIR with the file's content (false for a directory).
  def snapshot(dir)
    Dir.glob('**/*', File::FNM_DOTMATCH, base: dir).sort.to_h do |path|
      full = File.join(dir, path)
      [path, File.file?(full) && read_utf8(full)]
    end
  end

  # Body of a SKILL.md after its closing frontmatter line.
  def skill_body(path) = read_utf8(path).split(/^---$\n/, 3)[2]

  # CLAUDE.local.md the claude target writes for the same recipe, squashed in a fixture copy.
  def claude_reference
    ref_dir = Dir.mktmpdir
    FileUtils.cp_r(File.join(fixture_dir, '.'), ref_dir)
    original = Dir.pwd
    Dir.chdir(ref_dir)
    allow(Ruly::Services::MCPManager).to receive(:update_mcp_settings)
    capture_stdout { described_class.start(%w[squash demo -o claude.md]) }
    read_utf8('claude.md')
  ensure
    Dir.chdir(original)
    FileUtils.rm_rf(ref_dir)
  end

  context 'when squashing with -a claude-plugin' do
    let!(:stdout) { capture_stdout { described_class.start(%w[squash demo -a claude-plugin]) } }
    let(:manifest) { JSON.parse(read_utf8(manifest_path)) }

    it 'writes the manifest name, version and description' do
      expect(manifest.slice('name', 'version', 'description'))
        .to eq('description' => 'Claude Code plugin target fixture', 'name' => 'demo', 'version' => Ruly::VERSION)
    end

    it 'writes the author and the ruly ownership marker' do
      expect([manifest.dig('author', 'name'), manifest.dig('metadata', 'generator')]).to eq(['Fixture Author', 'ruly'])
    end

    it 'writes the rules skill with name frontmatter' do
      lines = read_utf8(rules_skill_path).lines.map(&:chomp)
      expect([lines.first, lines]).to match(['---', include('name: demo-rules')])
    end

    it 'writes the rules body the claude target writes to CLAUDE.local.md, with plugin-root script paths' do
      expect(skill_body(rules_skill_path))
        .to eq(claude_reference.gsub('.claude/scripts/notify.sh', '${CLAUDE_PLUGIN_ROOT}/scripts/notify.sh'))
    end

    it 'copies the recipe scripts into the plugin, executable' do
      expect(File.executable?(File.join(plugin_dir, 'scripts', 'notify.sh'))).to be(true)
    end

    it 'prints the always-on notice once' do
      expect(stdout.scan('cannot carry always-on instructions').size).to eq(1)
    end

    it 'names the rules skill and the always-on alternative in the notice' do
      expect(stdout).to include('/demo:demo-rules', '`ruly squash demo` (CLAUDE.local.md)')
    end

    it 'writes nothing into the project' do
      %w[.claude CLAUDE.local.md .mcp.json .mcp.yml CLAUDE.md].each do |path|
        expect(File.exist?(path)).to be(false), "expected #{path} to be absent"
      end
    end

    it 'writes no CLAUDE.md into the plugin' do
      expect(Dir.glob('**/CLAUDE.md', File::FNM_DOTMATCH, base: plugin_dir)).to be_empty
    end

    it 'writes recipe skills with their frontmatter' do
      expect(read_utf8(File.join(plugin_dir, 'skills/deploy/SKILL.md')).lines.map(&:chomp))
        .to include('description: Deploy the app')
    end

    it 'flattens the nested tdd skill' do
      expect([File.file?(File.join(plugin_dir, 'skills/tdd/SKILL.md')),
              File.exist?(File.join(plugin_dir, 'skills/tdd/SKILL'))])
        .to eq([true, false])
    end

    it 'writes the subagent skill and the command' do
      files = %w[skills/review/SKILL.md commands/ship.md].map { |f| File.join(plugin_dir, f) }
      expect(files).to all(satisfy { |f| File.file?(f) })
    end

    context 'with the helper agent file' do
      let(:agent_lines) { read_utf8(File.join(plugin_dir, 'agents/helper.md')).lines.map(&:chomp) }

      it 'keeps the model and lists the namespaced preloaded skill' do
        expect(agent_lines).to include('model: haiku', '- demo:review')
      end

      it 'has no permissionMode, hooks or mcpServers key' do
        expect(agent_lines.grep(/^(permissionMode|mcpServers|hooks):/)).to be_empty
      end
    end
  end

  context 'with hooks, MCP servers and scripts' do
    let(:servers) do
      {'grafana' => {'command' => 'mcp-grafana', 'env' => {'KEY' => 'fixture-secret-value', 'URL' => '${URL}'}}}
    end
    let(:stderr) { StringIO.new }
    let!(:stdout) do
      allow(Ruly::Services::MCPManager).to receive(:load_mcp_servers_from_config).with(['grafana']).and_return(servers)
      original = $stderr
      $stderr = stderr
      capture_stdout { described_class.start(%w[squash demo -a claude-plugin]) }
    ensure
      $stderr = original
    end

    it 'writes hooks/hooks.json with the quoted plugin-root command' do
      hooks = JSON.parse(read_utf8(File.join(plugin_dir, 'hooks/hooks.json')))
      expect(hooks.dig('hooks', 'Stop', 0, 'hooks', 0, 'command')).to eq('"${CLAUDE_PLUGIN_ROOT}/scripts/notify.sh"')
    end

    it 'writes .mcp.json with the recipe servers' do
      expect(JSON.parse(read_utf8(File.join(plugin_dir, '.mcp.json'))).dig('mcpServers', 'grafana', 'command'))
        .to eq('mcp-grafana')
    end

    it 'names the literal-secret server and never prints the value' do
      expect([stderr.string.include?('literal env/headers values for: grafana'),
              "#{stdout}#{stderr.string}".include?('fixture-secret-value')]).to eq([true, false])
    end

    it 'rewrites script references in the rules skill, skills and commands' do
      texts = %w[skills/demo-rules/SKILL.md skills/deploy/SKILL.md commands/ship.md]
              .map { |f| read_utf8(File.join(plugin_dir, f)) }
      expect(texts).to all(include('${CLAUDE_PLUGIN_ROOT}/scripts/notify.sh'))
      expect(texts).to all(satisfy { |t| !t.include?('.claude/scripts/notify.sh') })
    end

    it 'prints the skipped notice once' do
      expect(stdout.scan('claude-plugin target skips: subagent permissionMode').size).to eq(1)
    end

    it 'writes nothing into the project' do
      expect(%w[.claude .mcp.json CLAUDE.local.md].map { |f| File.exist?(f) }).to eq([false, false, false])
    end
  end

  context 'with a recipe skill named like the rules skill' do
    before do
      File.write('rules/skills/demo-rules.md', "---\ndescription: Clash\n---\n# Clash\n")
      skill_line = "      - rules/skills/deploy.md\n"
      File.write('.recipes.yml',
                 read_utf8('.recipes.yml').sub(skill_line, "#{skill_line}      - rules/skills/demo-rules.md\n"))
    end

    it 'exits 1 naming the collision' do
      expect_refusal(%w[squash demo -a claude-plugin], /collides with the generated rules skill/)
    end

    it 'writes nothing on a first run' do
      expect_refusal(%w[squash demo -a claude-plugin], /collides/)
      expect(Dir.glob('*ruly-plugin-demo*', File::FNM_DOTMATCH)).to be_empty
    end

    it 'keeps the previous plugin untouched' do
      recipe = read_utf8('.recipes.yml')
      File.write('.recipes.yml', recipe.sub("      - rules/skills/demo-rules.md\n", ''))
      run_cli('squash', 'demo', '-a', 'claude-plugin')
      before = snapshot(plugin_dir)
      File.write('.recipes.yml', recipe)
      expect_refusal(%w[squash demo -a claude-plugin], /collides/)
      expect([snapshot(plugin_dir), Dir.glob('.ruly-plugin-demo*')]).to eq([before, []])
    end
  end

  context 'when a subagent fails the build' do
    it 'keeps the previous plugin and leaves no backup behind' do
      run_cli('squash', 'demo', '-a', 'claude-plugin')
      manifest = read_utf8(manifest_path)
      File.write('rules/skills/demo-rules.md', "---\ndescription: Clash\n---\n# Clash\n")
      line = "      - rules/skills/review.md\n"
      File.write('.recipes.yml', read_utf8('.recipes.yml').sub(line, "#{line}      - rules/skills/demo-rules.md\n"))
      expect_refusal(%w[squash demo -a claude-plugin], /collides/)
      expect([read_utf8(manifest_path), read_utf8(rules_skill_path).include?('# Clash'),
              Dir.glob('.ruly-plugin-demo*')]).to eq([manifest, false, []])
    end
  end

  context 'with subagent skills' do
    def add_helper_skill(path, body = "---\ndescription: Helper skill\n---\n# Helper skill\n")
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, body)
      skill_line = "      - rules/skills/review.md\n"
      File.write('.recipes.yml', read_utf8('.recipes.yml').sub(skill_line, "#{skill_line}      - #{path}\n"))
    end

    it 'refuses one named like the rules skill and never overwrites the rules skill' do
      add_helper_skill('rules/skills/demo-rules.md')
      expect_refusal(%w[squash demo -a claude-plugin], /collides with the generated rules skill demo-rules/)
      expect(File.exist?(rules_skill_path) && read_utf8(rules_skill_path).include?('# Helper skill')).to be(false)
    end

    it 'refuses one whose flattened name is unsafe' do
      add_helper_skill('rules/skills/...md')
      expect_refusal(%w[squash demo -a claude-plugin], /unsafe plugin skill name '\.\.'/)
      expect(File.exist?(File.join(plugin_dir, 'skills', 'SKILL.md'))).to be(false)
    end

    it 'warns when one takes the name of a recipe skill from another file' do
      add_helper_skill('rules/helper/skills/deploy.md')
      expect { run_cli('squash', 'demo', '-a', 'claude-plugin') }
        .to output(%r{rules/skills/deploy.md and rules/helper/skills/deploy.md both map to plugin skill 'deploy'})
        .to_stderr
    end
  end

  context 'with the claude_plugin alias' do
    it 'writes the plugin dir' do
      run_cli('squash', 'demo', '-a', 'claude_plugin')
      expect(File.file?(manifest_path)).to be(true)
    end
  end

  context 'with -o DIR' do
    it 'writes the plugin into DIR and no default dir' do
      run_cli('squash', 'demo', '-a', 'claude-plugin', '-o', 'out/plugin')
      expect([File.file?('out/plugin/.claude-plugin/plugin.json'), File.exist?(plugin_dir)]).to eq([true, false])
    end
  end

  context 'with an existing plugin dir ruly did not generate' do
    before do
      FileUtils.mkdir_p(plugin_dir)
      File.write(File.join(plugin_dir, 'notes.txt'), "mine\n")
    end

    [%w[squash demo -a claude-plugin], %w[squash demo -a claude-plugin --dry-run]].each do |args|
      it "refuses #{args.join(' ')} with exit 1 and keeps the dir" do
        expect_refusal(args, /not generated by ruly/)
        expect(Dir.children(plugin_dir)).to eq(['notes.txt'])
      end
    end
  end

  context 'with a plugin dir ruly generated earlier' do
    it 'wipes stale files and rewrites it' do
      run_cli('squash', 'demo', '-a', 'claude-plugin')
      File.write(File.join(plugin_dir, 'stale.txt'), "old\n")
      run_cli('squash', 'demo', '-a', 'claude-plugin')
      expect([File.exist?(File.join(plugin_dir, 'stale.txt')), File.file?(rules_skill_path)]).to eq([false, true])
    end
  end

  context 'without a recipe' do
    it 'exits 1 asking for a recipe' do
      expect_refusal(%w[squash -a claude-plugin], /needs a recipe/)
    end
  end

  context 'when cleaning with -a claude-plugin' do
    before do
      run_cli('squash', 'demo', '-a', 'claude-plugin')
      FileUtils.mkdir_p('.claude')
      File.write('.claude/keep.txt', "keep\n")
      File.write('.mcp.json', "{}\n")
      File.write('CLAUDE.local.md', "# mine\n")
    end

    let(:kept) { %w[.claude/keep.txt .mcp.json CLAUDE.local.md] }

    it 'removes only the generated plugin dir' do
      run_cli('clean', 'demo', '-a', 'claude-plugin')
      expect([File.exist?(plugin_dir), kept.map { |f| File.exist?(f) }]).to eq([false, [true, true, true]])
    end

    it 'lists only the plugin dir on --dry-run and deletes nothing' do
      out = capture_stdout { described_class.start(%w[clean demo -a claude-plugin --dry-run]) }
      expect([out[/Would remove:.*/m].scan(/^   - .*/), File.exist?(plugin_dir)]).to eq([["   - #{plugin_dir}/"], true])
    end

    it 'keeps .claude/ on squash --clean' do
      run_cli('squash', 'demo', '-a', 'claude-plugin', '--clean')
      expect([File.file?(manifest_path), File.exist?('.claude/keep.txt')]).to eq([true, true])
    end
  end

  context 'when cleaning an unowned plugin dir' do
    it 'keeps it and says why' do
      FileUtils.mkdir_p(plugin_dir)
      File.write(File.join(plugin_dir, 'notes.txt'), "mine\n")
      expect do
        expect { described_class.start(%w[clean demo -a claude-plugin]) }.to output(/Already clean/).to_stdout
      end.to output(/not generated by ruly/).to_stderr
      expect(read_utf8(File.join(plugin_dir, 'notes.txt'))).to eq("mine\n")
    end
  end

  context 'with a dangerous or file -o' do
    it 'refuses -o . and writes nothing' do
      before = Dir.children('.').sort
      expect_refusal(%w[squash demo -a claude-plugin -o .], /Refusing to use/)
      expect(Dir.children('.').sort).to eq(before)
    end

    ['//', '~nouser'].each do |dir|
      it "refuses -o #{dir} cleanly and writes nothing" do
        before = Dir.children('.').sort
        expect_refusal(['squash', 'demo', '-a', 'claude-plugin', '-o', dir], /Refusing to use/)
        expect(Dir.children('.').sort).to eq(before)
      end
    end

    context 'when the working directory is reached through a symlink' do
      let(:work) { File.join(test_dir, 'work') }
      let(:link) { File.join(test_dir, 'lnk') }

      before do
        FileUtils.mkdir_p(work)
        FileUtils.cp_r(File.join(fixture_dir, '.'), work)
        FileUtils.mkdir_p(File.join(work, '.claude-plugin'))
        File.write(File.join(work, '.claude-plugin', 'plugin.json'), %({"metadata": {"generator": "ruly"}}\n))
        File.symlink(work, link)
        Dir.chdir(link)
      end

      it 'refuses squash -o through the symlink and keeps the working directory' do
        expect_refusal(['squash', 'demo', '-a', 'claude-plugin', '-o', link], /working directory/)
        expect([File.directory?(File.join(work, 'rules')), File.file?(File.join(work, '.recipes.yml'))])
          .to eq([true, true])
      end

      it 'refuses clean -o through the symlink' do
        expect { described_class.start(['clean', 'demo', '-a', 'claude-plugin', '-o', link]) }
          .to output(/Refusing to clean/).to_stderr.and output(/Already clean/).to_stdout
        expect(File.directory?(File.join(work, 'rules'))).to be(true)
      end
    end

    it 'refuses an existing file' do
      File.write('somefile.txt', "x\n")
      expect_refusal(%w[squash demo -a claude-plugin -o somefile.txt], /is not a directory/)
    end
  end

  context 'with --git-ignore and --git-exclude' do
    it 'adds the plugin dir to .gitignore' do
      run_cli('squash', 'demo', '-a', 'claude-plugin', '-i')
      expect(read_utf8('.gitignore').lines.map(&:chomp)).to include("#{plugin_dir}/")
    end

    it 'adds the plugin dir to .git/info/exclude' do
      FileUtils.mkdir_p('.git/info')
      run_cli('squash', 'demo', '-a', 'claude-plugin', '-I')
      expect(read_utf8('.git/info/exclude').lines.map(&:chomp)).to include("#{plugin_dir}/")
    end
  end

  context 'with --dry-run' do
    let!(:stdout) { capture_stdout { described_class.start(%w[squash demo -a claude-plugin --dry-run]) } }

    it 'prints the plugin dir, layout, script destination and notice' do
      expect(stdout).to include("Would create: #{plugin_dir}",
                                'Claude Code plugin: skills/demo-rules/SKILL.md, 2 skills, 1 commands, 1 subagents',
                                "Would copy script files to #{plugin_dir}/scripts/:",
                                'cannot carry always-on instructions')
    end

    it 'writes nothing' do
      expect([File.exist?(plugin_dir), File.exist?('.claude')]).to eq([false, false])
    end
  end

  context 'with an unsafe recipe name' do
    it 'exits 1 before writing anything' do
      File.write('.recipes.yml', "recipes:\n  'a b':\n    files:\n      - rules/base.md\n")
      expect_refusal(['squash', 'a b', '-a', 'claude-plugin'], /not a valid plugin name/)
      expect(Dir.glob('ruly-plugin-*')).to be_empty
    end
  end
end
