require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'liquid'
require_relative '../_plugins/cache-bust'

class CacheBustTest < Minitest::Test
  def test_css_cache_key_changes_when_a_sass_partial_changes
    filter = Object.new.extend(Jekyll::CacheBust)

    Dir.mktmpdir('spud-css-cache-test') do |directory|
      Dir.chdir(directory) do
        FileUtils.mkdir_p('_sass')
        File.write('_sass/_base.scss', 'body { color: black; }')
        original = filter.bust_css_cache('/assets/css/main.css')
        assert_equal original, filter.bust_css_cache('/assets/css/main.css')

        File.write('_sass/_base.scss', 'body { color: white; }')
        refute_equal original, filter.bust_css_cache('/assets/css/main.css')
      end
    end
  end
end
