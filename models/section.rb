class Section
  include DataMapper::Resource
  property :id, Serial
  property :title, String, :length => 256
  property :call_number, Integer
  property :description, Text
  property :days, String, :length => 256
  property :start_time, Float
  property :end_time, Float
  property :room, String, :length => 256
  property :building, String, :length => 256
  property :section_number, Integer
  property :section_key, String, :length => 256
  property :semester, String, :length => 256
  property :url, String, :length => 256
  property :enrollment, Integer
  property :max_enrollment, Integer

  belongs_to :instructor
  belongs_to :department
  belongs_to :subject
  belongs_to :course

  MAX_CONCURRENCY = 100


  # Crawls and parses an array of section urls, either updating or creating
  # new section objects to hold the scraped data
  def self.crawl(section_urls)
    hydra = Typhoeus::Hydra.new(:max_concurrency => MAX_CONCURRENCY)

    # build http requests for each section html page
    section_urls.each do |section_url|
      request = self.url_request(section_url)
      hydra.queue request
    end

    # run the request queue in parallel (blocking)
    hydra.run
  end

  # Return a request object for scraping the specified section url
  def self.url_request(url)
    request = Typhoeus::Request.new(url)
    request.on_complete do |response|

      if response.success?
        unless response.body.empty?
          self.update_or_create(url, response.body)
          puts "Crawled #{url}"
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

  # Either update or create a section object from the response body document
  def self.update_or_create(url, response_body)
    doc = Nokogiri::HTML(response_body)
    html = doc.to_html.gsub(/<\/?[^>]*>/, " ")

    # initialize section by section key
    match = html.match(/Section key\s*([^\n]+)/)
    section = Section.first(:section_key => match[1].strip)
    section = Section.create(:section_key => match[1].strip) if section.nil?

    # section number
    match = doc.css("title").first.content.strip.match(/section\s*0*([0-9]+)/)
    section.section_number = match[1].strip

    #title
    full_title = doc.css('td[colspan="2"]')[1].to_html.gsub(/<\/?[^>]*>/, " ").strip
    title = doc.css("title").first.content.strip
    section.title = full_title.gsub(title, "").gsub(/\s+/, " ").gsub("&amp;", "&").strip

    # subject
    match = section.section_key.match(/^[0-9]+([A-Z]+)/)
    section.subject = Subject.first(:abbreviation => match[1].strip)

    if section.subject.nil?
      section.subject = Subject.create(:abbreviation => match[1].strip)
    end

    #meta
    section.url = url
    section.semester = doc.css('meta[name="semes"]').first.attribute("content").value.strip
    section.description = doc.css('meta[name="description"]').first.attribute("content").value.strip

    instructor_name = doc.css('meta[name="instr"]').first.attribute("content").value.split( ", " )[0]
    section.instructor = Instructor.first(:name => instructor_name)

    if section.instructor.nil?
      section.instructor = Instructor.create(:name => instructor_name)
    end

    if html =~ /Department/
      match = html.match(/Department\s*([^\n]+)/)
      section.department = Department.first(:title => match[1].strip)

      if section.department.nil?
        section.department = Department.create(:title => match[1].strip)
      end
    end

    if html =~ /Call Number/
      match = html.match(/Call Number\s*([^\n]+)/)
      section.call_number = match[1].strip
    end

    if html =~ /Day \&amp; Time Location/
      match = html.match(/Day \&amp; Time Location\s*([A-Za-z]+)\s*([^-]+)-([^\s]+)\s?([^\n]+)?/)

      start_time = Time.parse(match[2].strip)
      end_time = Time.parse(match[3].strip)

      section.days = match[1].strip
      section.start_time = start_time.localtime.hour + (start_time.localtime.min/60.0)
      section.end_time = end_time.localtime.hour + (end_time.localtime.min/60.0)

      unless match[4].nil? or match[4].strip == "To be announced"
        match = match[4].strip.match( /([^\s]+)\s*(.+)/ )
        section.room = match[1].strip
        section.building = match[2].strip
      end
    end

    if html =~ /[0-9]+ students \([0-9]+ max/
      match = html.match(/([0-9]+) students \(([0-9]+) max/)
      section.enrollment = match[1].strip
      section.max_enrollment = match[2].strip
    end

    # course
    if html =~ /\n\s*Number\s*\n/
      match = html.match(/\n\s*Number\s*\n\s*([A-Z0-9]+)/)
      course_key = section.subject.abbreviation + match[1]
      section.course = Course.first(:course_key => course_key.strip)

      if section.course.nil?
        section.course = Course.create(:course_key => course_key.strip)
      end

    end

    section.save!
  end
end
