class Course
  include DataMapper::Resource
  property :id, Serial
  property :title, String, :length => 256
  property :course_key, String, :length => 256
  property :description, Text
  property :points, Float
  property :updated_at, DateTime

  has n, :sections

  BASE_URL = "http://www.college.columbia.edu/unify/getApi/bulletinSearch.php?courseIdentifierVar="
  MAX_CONCURRENCY = 100


  # Crawls and parses an array of section urls, either updating or creating
  # new section objects to hold the scraped data
  def self.crawl
    hydra = Typhoeus::Hydra.new(:max_concurrency => MAX_CONCURRENCY)

    # build http requests for each section html page
    Course.all.each do |course|
      request = course.url_request(School::ABRVS.values, hydra)
      hydra.queue request
    end

    # run the request queue in parallel (blocking)
    hydra.run
  end

  # Return a request object for scraping the specified section url
  def url_request(school_abbrs, request_queue)
    school_abbr = school_abbrs.slice!(0)
    url = self.url(school_abbr)

    request = Typhoeus::Request.new(url)
    request.on_complete do |response|
      if response.success?
        unless response.body.empty?
          doc = Nokogiri::HTML(response.body)
          if !doc.css("div.course-description").empty?
            self.update(url, school_abbr, doc)
            puts "Crawled #{url}"
          elsif !school_abbrs.empty?
            request_queue.queue self.url_request(school_abbrs, request_queue)
          end
        else
          puts "FAILED #{url}"
        end
      elsif response.timed_out?
        puts "RESPONSE TIMED OUT!!!"
      elsif response.code == 0
        puts "DID NOT RECEIVE HTTP RESPONSE!!!"
      else
        puts "NON-SUCCESSFUL HTTP RESPONSE!!!"
      end
    end

    # return the request object for post-response processing
    request
  end

  # Returns url of api course lookup call
  def url(school_abbr)
    "#{BASE_URL}#{self.course_key}&school=#{school_abbr}"
  end

  # Updates course object using response body content
  def update(url, school_abbr, doc)
    brief = ""
    if school_abbr == 'CC' or school_abbr == 'GSAS'
      doc.css("div.course-description > p").each do |p|
        if p.to_html.gsub("\n", "").match(/<strong>.*<\/strong>/)
          brief = p.to_html.gsub("\n", "").gsub(/<em>Not offered in [0-9]+-[0-9]+.<\/em>/, "").gsub(/\s+/, " ").gsub(/&amp;/, "&").strip
          break
        end
      end
    else
      brief = doc.css("div.course-description").first.to_html.gsub("\n", "")
    end

    # title
    match = brief.gsub(/<\/?strong>/, '#').match( /#([^#]+)/)
    self.title = match[1].gsub(/<\/?[^>]*>/, " ").gsub(/([A-Z]{2,4}\s+)?[A-Z]\s?[0-9]+([xy]+)?(\sand\sy|\sor\sy)?-?(\s*\*\s*)?\.?/, "").gsub(/\s+/, " ").strip
    self.title.gsub!(/\s*\(\s*(S|s)ection\s*[0-9]+\s*\)\s*/, '')
    self.title.gsub!(/\..*/, '')

    # description
    match = brief.match(/<\/strong>\s*(<em>\s*[0-9.]+\s*pts\.[^<]*<\/em>)?\s*(.*)$/)
    self.description = match[2].gsub(/<\/?[^>]*>/, " ").gsub(/\s+/, " ").strip

    # points
    match = brief.match(/([0-9.]+)\s*pts\./)
    match = brief.match(/([0-9.]+)\s*points/) if match.nil?

    unless match.nil?
      self.points = match[1].gsub(/<\/?[^>]*>/, " ").gsub( /\s+/, " ").strip
    end

    # persist changes
    self.updated_at = Time.now
    self.save!
  end
end
