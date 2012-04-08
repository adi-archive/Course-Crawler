require "dm-validations"

class Section
  include DataMapper::Resource
  property :id, Serial
  property :title, String, :length => 256
  # TODO - this should be a string...
  property :call_number, Integer
  property :description, Text
  property :days, String, :length => 256
  property :start_time, Float
  property :end_time, Float
  property :room, String, :length => 256
  property :building, String, :length => 256
  # TODO - this should be a string...
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

  # TODO - add validations

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

    puts "\n-------------------\n"

    doc = Nokogiri::HTML(response_body)
    html = doc.to_html.gsub(/<\/?[^>]*>/, " ")

    # initialize section by section key
    match = html.match(/Section key\s*([^\n]+)/)
    section = Section.first(:section_key => match[1].strip)

    # TODO - don't update too frequently
    if section.nil?
      puts "section #{match[1].strip} is nil"
      section = Section.new(:section_key => match[1].strip)
    end

    # section number
    match = doc.css("title").first.content.strip.match(/section\s*0*([0-9]+)/)
    section.section_number = match[1].strip.to_i

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
      doc.css('tr').each do |tr|
        if tr.children.first.content =~ /Department/  
         match = tr.children.css('td')[1].content
         break
        end  
      end
      section.department = Department.first(:title => match)

      if section.department.nil?
        puts "Department initialized: #{match[1].strip}"
        section.department = Department.create(:title => match)
      end
    end

    if html =~ /Call Number/
      match = html.match(/Call Number\s*([^\n]+)/)
      section.call_number = match[1].strip.to_i
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
      section.enrollment = match[1].strip.to_i
      section.max_enrollment = match[2].strip.to_i
    end

    # course
    if html =~ /\n\s*Number\s*\n/
      match = html.match(/\n\s*Number\s*\n\s*([A-Z0-9]+)/)
      course_key = section.subject.abbreviation + match[1]
      section.course = Course.first(:course_key => course_key.strip)
      if Course.first(:course_key => course_key.strip).nil?
        puts "Course not found for #{course_key.strip}!"
        section.course = Course.create(:course_key => course_key.strip)
      end
    end

    match = html.match(/\n\s*Number\s*\n\s*([A-Z0-9]+)/)
    course_key = section.subject.abbreviation + match[1]

=begin
    puts "Section #{section.id}\t#{course_key}\t#{section.course_id} saving"
    puts "Info: #{section.instructor_id}\t#{section.course_id}\t#{section.department_id}\t#{section.subject_id}"

    puts "course #{Course.first(:id => section.course_id).inspect}"
    puts "instructor#{Instructor.first(:id => section.instructor_id).inspect}"
    puts "department #{Department.first(:id => section.department_id).inspect}"
    puts "subject #{Subject.first(:id => section.subject_id).inspect}"


    puts "id #{section.id}"
    puts "title #{section.title}"
    puts "call_number #{section.call_number}"
    puts "description #{section.description}"
    puts "days #{section.days}"
    puts "start_time #{section.start_time}"
    puts "end_time #{section.end_time}"
    puts "room #{section.room}"
    puts "building #{section.building}"
    puts "section_number #{section.section_number}"
    puts "section_key #{section.section_key}"
    puts "semester #{section.semester}"
    puts "url #{section.url}"
    puts "enrollment #{section.enrollment}"
    puts "max_enrollment #{section.max_enrollment}"
=end

    p section

    section.save

  end
end
