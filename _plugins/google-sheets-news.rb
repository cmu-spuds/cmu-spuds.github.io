require 'net/http'
require 'uri'
require 'csv'
require 'date'

module GoogleSheetsNews
  class GoogleSheetsNewsGenerator < Jekyll::Generator
    safe true
    priority :high

    def generate(site)
      return unless site.config['google_sheets_news']
      
      config = site.config['google_sheets_news']
      return unless config['enabled']
      
      # Support both CSV URL and sheet ID
      csv_url = config['csv_url']
      sheet_id = config['sheet_id']
      gid = config['gid'] || '0'  # Sheet tab ID, default to first sheet
      
      # If CSV URL is provided, use it directly; otherwise construct from sheet_id
      if csv_url && !csv_url.strip.empty?
        csv_url = csv_url.strip
      elsif sheet_id && !sheet_id.strip.empty?
        # Google Sheets CSV export URL format
        csv_url = "https://docs.google.com/spreadsheets/d/#{sheet_id.strip}/export?format=csv&gid=#{gid}"
      else
        Jekyll.logger.warn "Google Sheets News: No csv_url or sheet_id provided"
        return
      end
      
      begin
        if config['csv_file']
          # CI captures both feeds once, so the build and its saved state agree.
          csv_data = File.read(config['csv_file'])
        else
          Jekyll.logger.info "Fetching news from Google Sheets..."
        
          uri = URI(csv_url)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true if uri.scheme == 'https'
        
          request = Net::HTTP::Get.new(uri.request_uri)
          response = http.request(request)
        
          # Follow redirects (Google Sheets published URLs often redirect)
          max_redirects = 5
          redirect_count = 0
          while response.is_a?(Net::HTTPRedirection) && redirect_count < max_redirects
            redirect_count += 1
            redirect_uri = URI(response['location'])
            if redirect_uri.relative?
              redirect_uri = uri + redirect_uri
            end
            Jekyll.logger.info "Following redirect to: #{redirect_uri}"
            http = Net::HTTP.new(redirect_uri.host, redirect_uri.port)
            http.use_ssl = true if redirect_uri.scheme == 'https'
            request = Net::HTTP::Get.new(redirect_uri.request_uri)
            response = http.request(request)
          end
        
          if response.code != '200'
            Jekyll.logger.warn "Failed to fetch Google Sheets: HTTP #{response.code}"
            return
          end
        
          csv_data = response.body
        end
        news_items = parse_csv(csv_data)
        
        # Generators run after Jekyll reads collection files. Update the loaded
        # documents so this build uses fresh news, without modifying the source.
        collection = site.collections.fetch('news')
        imported_documents = news_items.map do |item|
          create_news_document(site, collection, item)
        end
        local_documents = collection.docs.reject { |doc| File.basename(doc.path).start_with?('gs_') }
        collection.docs.replace((local_documents + imported_documents).sort)
        
        Jekyll.logger.info "Successfully imported #{news_items.length} news items from Google Sheets"
        
      rescue => e
        Jekyll.logger.error "Error fetching Google Sheets news: #{e.message}"
        Jekyll.logger.error e.backtrace.join("\n")
      end
    end
    
    private
    
    def parse_csv(csv_data)
      items = []
      csv = CSV.parse(csv_data, headers: true)
      
      csv.each do |row|
        # Expected columns: date, title, inline (optional), url (optional)
        next if row['date'].nil? || row['date'].strip.empty?
        next if row['title'].nil? || row['title'].strip.empty?
        
        # Use 'content' column if available, otherwise use 'title'
        content = row['content']&.strip
        content = row['title'].strip if content.nil? || content.empty?
        
        item = {
          'date' => parse_date(row['date']),
          'title' => row['title'].strip,
          'inline' => row['inline']&.strip&.downcase == 'true' || row['inline']&.strip == '1',
          'url' => row['url']&.strip,
          'content' => content
        }
        
        items << item
      end
      
      # Sort by date descending (newest first)
      items.sort_by { |item| item['date'] }.reverse
    end
    
    def parse_date(date_str)
      # Try multiple date formats
      begin
        Date.parse(date_str)
      rescue
        # If parsing fails, try common formats
        formats = ['%Y-%m-%d', '%m/%d/%Y', '%d/%m/%Y', '%Y/%m/%d']
        formats.each do |format|
          begin
            return Date.strptime(date_str, format)
          rescue
            next
          end
        end
        # Default to today if all parsing fails
        Date.today
      end
    end
    
    def create_news_document(site, collection, item)
      # Preserve the paths used by existing Google Sheets announcements.
      date_str = item['date'].strftime('%Y-%m-%d')
      safe_title = item['title'].downcase.gsub(/[^a-z0-9]+/, '-')[0..30]
      filename = "gs_#{date_str}_#{safe_title}.md"
      filepath = File.join(collection.directory, filename)

      document = Jekyll::Document.new(filepath, site: site, collection: collection)
      document.merge_data!({
        'layout' => 'post',
        'title' => item['title'],
        'date' => item['date'].strftime('%Y-%m-%d 00:00:00-0000'),
        'inline' => item['inline'],
        'related_posts' => false
      })
      document.content = item['content']
      document.post_read
      document
    end
  end
end
