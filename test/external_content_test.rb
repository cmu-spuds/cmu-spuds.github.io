require 'minitest/autorun'
require 'tmpdir'
require_relative '../bin/external_content'

class ExternalContentTest < Minitest::Test
  def setup
    @directory = Dir.mktmpdir('spud-content-test')
    @baseline = File.join(@directory, 'baseline.json')
    @config = {
      'jekyll_get_json' => [
        { 'data' => 'resume', 'json' => 'assets/json/resume.json' },
        { 'data' => 'publications', 'json' => 'https://example.test/papers.json' }
      ],
      'google_sheets_news' => { 'enabled' => true, 'csv_url' => 'https://example.test/news.csv' }
    }
    @paper = { 'title' => 'A paper', 'year' => 2026, 'authors' => [{ 'name' => 'An Author' }], 'downloads' => 10, 'likes' => 2 }
    @feeds = {
      'https://example.test/papers.json' => JSON.generate([@paper]),
      'https://example.test/news.csv' => "date,title,content,inline,url\n2026-01-01,News,Some news,true,\n"
    }
  end

  def teardown
    FileUtils.remove_entry(@directory)
  end

  def capture
    ExternalContent.capture(@config, fetcher: ->(url) { @feeds.fetch(url) })
  end

  def test_identical_content_ignores_json_formatting_and_counter_changes
    original = capture.fetch(:state)
    @paper['downloads'] = 999
    @paper['likes'] = 100
    @feeds['https://example.test/papers.json'] = JSON.pretty_generate([@paper.to_a.reverse.to_h])
    assert_equal original, capture.fetch(:state)
  end

  def test_publication_edits_additions_and_deletions_are_changes
    original = capture.fetch(:state)
    [
      [@paper.merge('title' => 'A corrected title')],
      [@paper.merge('authors' => [{ 'name' => 'Another Author' }])],
      [@paper.merge('awards' => [{ 'body' => 'Best Paper' }])],
      [@paper.merge('pdf' => 'https://example.test/new.pdf')],
      [@paper, { 'title' => 'A new paper' }],
      []
    ].each do |papers|
      @feeds['https://example.test/papers.json'] = JSON.generate(papers)
      refute_equal original, capture.fetch(:state)
    end
  end

  def test_news_edits_and_deletions_are_changes
    original = capture.fetch(:state)
    @feeds['https://example.test/news.csv'] = "date,title,content,inline,url\n2026-01-01,News,Edited news,true,\n"
    refute_equal original, capture.fetch(:state)
    @feeds['https://example.test/news.csv'] = "date,title,content,inline,url\n"
    refute_equal original, capture.fetch(:state)
  end

  def test_csv_column_order_line_endings_and_empty_rows_do_not_trigger_builds
    original = capture.fetch(:state)
    @feeds['https://example.test/news.csv'] = "title,date,inline,content,url\r\nNews,2026-01-01,true,Some news,\r\n,,,,\r\n"
    assert_equal original, capture.fetch(:state)
  end

  def test_initial_build_is_required_and_unchanged_baseline_is_not_rewritten
    state = capture.fetch(:state)
    assert ExternalContent.changed?(state, @baseline)
    File.write(@baseline, JSON.generate(state))
    original = File.read(@baseline)
    refute ExternalContent.changed?(state, @baseline)
    assert ExternalContent.changed?(state.merge('news' => 'changed'), @baseline)
    assert_equal original, File.read(@baseline)
  end

  def test_snapshot_overrides_use_exact_captured_inputs
    snapshot = capture
    ExternalContent.write_snapshot(snapshot, @config, @directory)
    overrides = YAML.load_file(File.join(@directory, 'config.yml'))
    sources = overrides.fetch('jekyll_get_json')
    assert_equal @config.fetch('jekyll_get_json').first, sources.first
    assert_equal snapshot.fetch(:publications_json), File.read(sources.last.fetch('json'))
    assert_equal snapshot.fetch(:news_csv), File.read(overrides.fetch('google_sheets_news').fetch('csv_file'))
    assert_equal snapshot.fetch(:state), JSON.parse(File.read(File.join(@directory, 'state.json')))
  end

  def test_invalid_feeds_are_rejected
    @feeds['https://example.test/news.csv'] = '<html>Service unavailable</html>'
    assert_raises(ArgumentError) { capture }
    @feeds['https://example.test/papers.json'] = '{}'
    assert_raises(ArgumentError) { capture }
  end

  def test_checker_emits_false_for_unchanged_content
    File.write(@baseline, JSON.generate(capture.fetch(:state)))
    config_path = File.join(@directory, 'site.yml')
    output_path = File.join(@directory, 'outputs')
    File.write(config_path, YAML.dump(@config))
    capture_io do
      ExternalContent.stub(:fetch, ->(url) { @feeds.fetch(url) }) do
        assert_equal 0, ExternalContent.run(['check', '--config', config_path, '--baseline', @baseline], output_path: output_path)
      end
    end
    assert_equal "changed=false\n", File.read(output_path)
  end

  def test_failed_fetch_does_not_mark_content_as_deployed_or_request_a_build
    original = JSON.generate(capture.fetch(:state))
    File.write(@baseline, original)
    config_path = File.join(@directory, 'site.yml')
    output_path = File.join(@directory, 'outputs')
    File.write(config_path, YAML.dump(@config))
    capture_io do
      ExternalContent.stub(:fetch, ->(_url) { raise IOError, 'Feed unavailable' }) do
        assert_equal 1, ExternalContent.run(['check', '--config', config_path, '--baseline', @baseline], output_path: output_path)
      end
    end
    assert_equal original, File.read(@baseline)
    refute File.exist?(output_path)
    refute File.exist?(File.join(@directory, 'state.json'))
  end

  def test_checker_requests_a_build_when_news_changes
    original = JSON.generate(capture.fetch(:state))
    File.write(@baseline, original)
    @feeds['https://example.test/news.csv'] = "date,title,content,inline,url\n2026-01-01,News,Updated news,true,\n"
    config_path = File.join(@directory, 'site.yml')
    output_path = File.join(@directory, 'outputs')
    File.write(config_path, YAML.dump(@config))
    capture_io do
      ExternalContent.stub(:fetch, ->(url) { @feeds.fetch(url) }) do
        assert_equal 0, ExternalContent.run(['check', '--config', config_path, '--baseline', @baseline], output_path: output_path)
      end
    end
    assert_equal "changed=true\n", File.read(output_path)
    assert_equal original, File.read(@baseline)
  end
end
