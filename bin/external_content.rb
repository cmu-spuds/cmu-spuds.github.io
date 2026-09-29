require 'csv'
require 'digest'
require 'fileutils'
require 'json'
require 'net/http'
require 'optparse'
require 'uri'
require 'yaml'

# Shared by the lightweight feed check and the deployment's input snapshot.
module ExternalContent
  extend self

  NEWS_FIELDS = %w[date title content inline url].freeze
  PUBLICATION_COUNTERS = %w[downloads likes].freeze

  def fetch(url, redirects = 5)
    uri = URI(url)
    raise ArgumentError, 'Feed URL must use HTTP or HTTPS' unless %w[http https].include?(uri.scheme)

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https',
                               open_timeout: 10, read_timeout: 30) do |http|
      http.get(uri.request_uri, 'User-Agent' => 'SPUD-Lab-content-check')
    end
    case response
    when Net::HTTPSuccess
      response.body.force_encoding(Encoding::UTF_8)
    when Net::HTTPRedirection
      raise IOError, 'Too many feed redirects' if redirects.zero?

      fetch((uri + response.fetch('location')).to_s, redirects - 1)
    else
      raise IOError, "Feed returned HTTP #{response.code}: #{uri.host}"
    end
  end

  def canonical(value)
    case value
    when Hash
      value.keys.sort.to_h { |key| [key, canonical(value.fetch(key))] }
    when Array
      value.map { |item| canonical(item) }
    else
      value
    end
  end

  def digest(value)
    Digest::SHA256.hexdigest(JSON.generate(canonical(value)))
  end

  def capture(config, fetcher: method(:fetch))
    publications_source = config.fetch('jekyll_get_json').find { |item| item['data'] == 'publications' }
    raise ArgumentError, 'No publications feed configured' unless publications_source

    publications_json = fetcher.call(publications_source.fetch('json'))
    publications = JSON.parse(publications_json)
    unless publications.is_a?(Array) && publications.all? { |paper| paper.is_a?(Hash) && paper['title'].is_a?(String) }
      raise ArgumentError, 'Publications feed must contain an array of papers with titles'
    end

    # These counters change as people visit Sauvik's site; they are not rendered here.
    publication_content = publications.map { |paper| paper.reject { |key, _| PUBLICATION_COUNTERS.include?(key) } }
    state = { 'version' => 1, 'publications' => digest(publication_content), 'news' => nil }
    news = config['google_sheets_news'] || {}
    news_csv = nil
    if news['enabled']
      csv_url = news['csv_url'].to_s.strip
      if csv_url.empty? && !news['sheet_id'].to_s.strip.empty?
        csv_url = "https://docs.google.com/spreadsheets/d/#{news['sheet_id'].strip}/export?format=csv&gid=#{news.fetch('gid', '0')}"
      end
      raise ArgumentError, 'No news feed configured' if csv_url.empty?

      news_csv = fetcher.call(csv_url).delete_prefix("\uFEFF")
      rows = CSV.parse(news_csv, headers: true)
      unless (%w[date title] - rows.headers.compact).empty?
        raise ArgumentError, 'News CSV must include date and title columns'
      end
      news_content = rows.map do |row|
        NEWS_FIELDS.to_h { |field| [field, row[field].to_s.strip] }
      end.reject { |row| row['date'].empty? || row['title'].empty? }
      state['news'] = digest(news_content)
    end
    { state: state, publications_json: publications_json, news_csv: news_csv }
  end

  def changed?(state, baseline_path)
    !File.file?(baseline_path) || JSON.parse(File.read(baseline_path)) != state
  end

  def write_snapshot(snapshot, config, directory)
    directory = File.expand_path(directory)
    FileUtils.mkdir_p(directory)
    publications_path = File.join(directory, 'publications.json')
    File.write(publications_path, snapshot.fetch(:publications_json))
    overrides = {
      'jekyll_get_json' => config.fetch('jekyll_get_json').map do |source|
        source['data'] == 'publications' ? source.merge('json' => publications_path) : source
      end
    }
    if snapshot[:news_csv]
      news_path = File.join(directory, 'news.csv')
      File.write(news_path, snapshot[:news_csv])
      overrides['google_sheets_news'] = config.fetch('google_sheets_news').merge('csv_file' => news_path)
    end
    File.write(File.join(directory, 'config.yml'), YAML.dump(overrides))
    File.write(File.join(directory, 'state.json'), JSON.pretty_generate(snapshot.fetch(:state)) + "\n")
  end

  def run(argv, output_path: ENV['GITHUB_OUTPUT'])
    command = argv.shift
    options = { config: '_config.yml' }
    OptionParser.new do |parser|
      parser.on('--config PATH') { |path| options[:config] = path }
      parser.on('--baseline PATH') { |path| options[:baseline] = path }
      parser.on('--output-dir PATH') { |path| options[:output_dir] = path }
    end.parse!(argv)
    unless %w[check prepare].include?(command)
      raise ArgumentError, 'Usage: external_content.rb check --baseline PATH | prepare --output-dir PATH'
    end
    required_option = command == 'check' ? :baseline : :output_dir
    raise ArgumentError, "Missing --#{required_option.to_s.tr('_', '-')}" unless options[required_option]

    config = YAML.load_file(options.fetch(:config))
    snapshot = capture(config)
    if command == 'check'
      changed = changed?(snapshot.fetch(:state), options.fetch(:baseline))
      puts(changed ? 'External content changed; requesting a build.' : 'External content is unchanged; no build needed.')
      File.open(output_path, 'a') { |file| file.puts "changed=#{changed}" } if output_path
    else
      write_snapshot(snapshot, config, options.fetch(:output_dir))
      puts 'Captured publication and news inputs for this build.'
    end
    0
  rescue StandardError => error
    warn "External content check failed: #{error.message}"
    1
  end
end

exit ExternalContent.run(ARGV) if $PROGRAM_NAME == __FILE__
