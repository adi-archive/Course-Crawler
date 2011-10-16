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

  def self.crawl
    subjects = Subject.all
    num_subjects = subjects.size
    start_time = Time.now
    sections_crawled = 0

    subjects.each_with_index do |s, index|
      unless s.abbreviation.nil?
        url = "http://www.columbia.edu/cu/bulletin/uwb/subj/#{s.abbreviation}"
        begin
          doc = Nokogiri::HTML(open(url))
        rescue
          puts "Bad subject URL: #{url}"
          next
        end

        section_urls = doc.css('a')
        sections_per_minute = (sections_crawled*60/(Time.now-start_time)).round(1)
        sections_crawled = sections_crawled + section_urls.length

        puts "(" << (index+1).to_s << " of " << num_subjects.to_s << "): " << url << " (" << section_urls.length.to_s << " sections; " << sections_per_minute.to_s << " sections/min)"
        section_urls.each { |a| Section.update_or_create( url + "/" + a.content ) if a.content =~ /[A-Z0-9]+-[0-9]+-[0-9]+/ }
      end
    end
  end

  def self.update_or_create( url )
    require 'open-uri'

    begin
      doc = Nokogiri::HTML(open( url ))
    rescue
      puts "Bad section url"
      return
    end

    puts "Crawling #{url}"
    html = doc.to_html.gsub(/<\/?[^>]*>/, " ")

    # initialize section by section key
    match = html.match(/Section key\s*([^\n]+)/)
    section = Section.first( :section_key => match[1].strip )
    section = Section.create( :section_key => match[1].strip ) if section.nil?

    # only update section if it has not been touch in the last 12 hours
    # return section unless section.call_number.nil?

    # section number
    match = doc.css("title").first.content.strip.match( /section\s*0*([0-9]+)/ )
    section.section_number = match[1].strip

    #title
    full_title = doc.css( 'td[colspan="2"]' )[1].to_html.gsub(/<\/?[^>]*>/, " ").strip
    title = doc.css("title").first.content.strip
    section.title = full_title.gsub( title, "" ).gsub( /\s+/, " " ).gsub( "&amp;", "&" ).strip

    # subject
    match = section.section_key.match( /^[0-9]+([A-Z]+)/ )
    section.subject = Subject.first( :abbreviation => match[1].strip )
    section.subject = Subject.create( :abbreviation => match[1].strip ) if section.subject.nil?

    #meta
    section.url = url
    section.semester = doc.css('meta[name="semes"]').first.attribute("content").value.strip
    section.description = doc.css('meta[name="description"]').first.attribute("content").value.strip

    instructor_name = doc.css('meta[name="instr"]').first.attribute("content").value.split( ", " )[0]
    section.instructor = Instructor.first( :name => instructor_name )
    section.instructor = Instructor.create( :name => instructor_name ) if section.instructor.nil?

    if html =~ /Department/
      match = html.match(/Department\s*([^\n]+)/)
      section.department = Department.first( :title => match[1].strip )
      section.department = Department.create( :title => match[1].strip ) if section.department.nil?
    end

    if html =~ /Call Number/
      match = html.match(/Call Number\s*([^\n]+)/)
      section.call_number = match[1].strip
    end

    if html =~ /Day \&amp; Time Location/
      match = html.match(/Day \&amp; Time Location\s*([A-Za-z]+)\s*([^-]+)-([^\s]+)\s?([^\n]+)?/)

      start_time = Time.parse( match[2].strip )
      end_time = Time.parse( match[3].strip )

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
      match = html.match( /([0-9]+) students \(([0-9]+) max/ )
      section.enrollment = match[1].strip
      section.max_enrollment = match[2].strip
    end

    # course
    if html =~ /\n\s*Number\s*\n/
      match = html.match( /\n\s*Number\s*\n\s*([A-Z0-9]+)/ )
      course_key = section.subject.abbreviation + match[1]
      section.course = Course.first( :course_key => course_key.strip )
      section.course = Course.create( :course_key => course_key.strip ) if section.course.nil?
 
    end

    section.save!
  end
end
