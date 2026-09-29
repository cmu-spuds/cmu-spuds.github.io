require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'jekyll'
require_relative '../_plugins/google-sheets-news'

class GoogleSheetsNewsTest < Minitest::Test
  Response = Struct.new(:code, :body)
  Connection = Struct.new(:response, :use_ssl) do
    def request(_request)
      raise response if response.is_a?(Exception)

      response
    end
  end

  def setup
    @directory = Dir.mktmpdir('spud-news-test')
    @source = File.join(@directory, 'source')
    @destination = File.join(@directory, 'site')
    FileUtils.mkdir_p(File.join(@source, '_news'))
    FileUtils.mkdir_p(File.join(@source, '_layouts'))
    File.write(File.join(@source, '_layouts', 'post.html'), '<h1>{{ page.title }}</h1>{{ content }}')
    File.write(File.join(@source, 'index.html'), <<~LIQUID)
      ---
      ---
      {% for item in site.news reversed %}{{ item.title }}: {{ item.content }}{% endfor %}
    LIQUID
    write_news('gs_2024-05-17_existing-announcement.md', 'Existing announcement', '2024-05-17', 'Stale content')
    write_news('gs_removed.md', 'Removed announcement', '2023-01-01', 'Deleted sheet row')
    write_news('manual.md', 'Manual announcement', '2025-01-01', 'Keep this local news')
    @original_sources = source_files
  end

  def teardown
    FileUtils.remove_entry(@directory)
  end

  def test_first_build_renders_fresh_news_and_preserves_manual_news_without_changing_sources
    site = build(Response.new('200', <<~CSV))
      date,title,content,inline
      2024-05-17,Existing announcement,Updated **content**,true
      2026-03-25,New announcement,Fresh **news**,false
    CSV

    output = File.read(File.join(@destination, 'index.html'))
    assert_includes output, 'Fresh <strong>news</strong>'
    assert_includes output, 'Updated <strong>content</strong>'
    assert_includes output, 'Keep this local news'
    refute_includes output, 'Stale content'
    refute_includes output, 'Deleted sheet row'
    assert_operator output.index('New announcement'), :<, output.index('Manual announcement')
    assert_operator output.index('Manual announcement'), :<, output.index('Existing announcement')
    assert_equal 3, site.collections.fetch('news').docs.length
    assert_equal @original_sources, source_files

    page = File.read(File.join(@destination, 'news', 'gs_2026-03-25_new-announcement', 'index.html'))
    assert_includes page, '<h1>New announcement</h1>'
    assert_includes page, 'Fresh <strong>news</strong>'
  end

  def test_http_failure_uses_checked_in_news
    assert_fallback(Response.new('503', 'Unavailable'))
  end

  def test_network_failure_uses_checked_in_news
    assert_fallback(IOError.new('Connection failed'))
  end

  def test_malformed_csv_uses_checked_in_news
    assert_fallback(Response.new('200', "date,title\n\"unterminated"))
  end

  def test_empty_sheet_removes_imported_news_but_preserves_manual_news
    site = build(Response.new('200', "date,title,content,inline\n"))

    assert_equal ['Manual announcement'], site.collections.fetch('news').docs.map { |doc| doc.data['title'] }
    assert_equal @original_sources, source_files
  end

  private

  def write_news(filename, title, date, content)
    File.write(File.join(@source, '_news', filename), <<~MARKDOWN)
      ---
      layout: post
      title: #{title}
      date: #{date}
      inline: true
      ---
      #{content}
    MARKDOWN
  end

  def source_files
    Dir.glob(File.join(@source, '**', '*')).select { |path| File.file?(path) }.to_h do |path|
      [path, File.binread(path)]
    end
  end

  def build(response)
    site = Jekyll::Site.new(Jekyll.configuration(
      'source' => @source,
      'destination' => @destination,
      'disable_disk_cache' => true,
      'plugins' => [],
      'plugins_dir' => [],
      'quiet' => true,
      'future' => true,
      'collections' => { 'news' => { 'output' => true, 'permalink' => '/news/:path/' } },
      'google_sheets_news' => { 'enabled' => true, 'csv_url' => 'https://example.test/news.csv' }
    ))
    capture_subprocess_io do
      Net::HTTP.stub(:new, Connection.new(response)) { site.process }
    end
    site
  end

  def assert_fallback(response)
    site = build(response)
    output = File.read(File.join(@destination, 'index.html'))
    assert_includes output, 'Stale content'
    assert_includes output, 'Deleted sheet row'
    assert_includes output, 'Keep this local news'
    assert_equal 3, site.collections.fetch('news').docs.length
    assert_equal @original_sources, source_files
  end
end
