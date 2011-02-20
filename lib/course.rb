class Course < ActiveRecord::Base
  has_many :sections

  def self.update_or_create( course_key )
    require 'open-uri'
    error_message = "I'm sorry. At the moment, there are no courses that correspond to your search criteria."

    course = Course.find_or_create_by_course_key( course_key )
    return course unless course.title.nil? or course.updated_at < (Time.now-12.hours)
    
    puts course_key + ": loading course data"
    
    url = "http://www.college.columbia.edu/unify/getApi/bulletinSearch.php?courseIdentifierVar=" + course_key
    doc = nil
    school = nil
    [ 'CC', 'EN', 'BC', 'GSAS', 'CE', 'SIPA', 'GS' ].each do |s|
      begin
        doc = Nokogiri::HTML(open( url + '&school=' + s ))
        unless doc.to_html.match( error_message )
          school = s
          break
        end
      rescue
        next
      end
    end

    if doc.to_html.match( error_message ) or doc.nil?
      course.destroy
      return nil
    end

    brief = ""
    if school == 'CC'or school == 'GSAS'
      doc.css( "div.course-description > p" ).each do |p|
        if p.to_html.gsub( "\n", "" ).match( /<strong>.*<\/strong>/ )
          brief = p.to_html.gsub( "\n", "" ).gsub(/<em>Not offered in [0-9]+-[0-9]+.<\/em>/, "").gsub( /\s+/, " " ).gsub( /&amp;/, "&" ).strip
          break
        end
      end
    else
      brief = doc.css( "div.course-description" ).first.to_html.gsub( "\n", "" )
    end

    # title
    match = brief.gsub( /<\/?strong>/, '#' ).match( /#([^#]+)/ )
    course.title = match[1].gsub( /<\/?[^>]*>/, " " ).gsub( /([A-Z]{2,4}\s+)?[A-Z]\s?[0-9]+([xy]+)?(\sand\sy|\sor\sy)?-?(\s*\*\s*)?\.?/, "" ).gsub( /\s+/, " " ).strip
    course.title.gsub!( /\s*\(\s*(S|s)ection\s*[0-9]+\s*\)\s*/, '' )
    course.title.gsub!( /\..*/, '' )
    
    # description
    match = brief.match( /<\/strong>\s*(<em>\s*[0-9.]+\s*pts\.[^<]*<\/em>)?\s*(.*)$/ )
    course.description = match[2].gsub(/<\/?[^>]*>/, " ").gsub( /\s+/, " " ).strip

    # points
    match = brief.match( /([0-9.]+)\s*pts\./ )
    match = brief.match( /([0-9.]+)\s*points/ ) if match.nil? 

    course.points = match[1].gsub(/<\/?[^>]*>/, " ").gsub( /\s+/, " " ).strip unless match.nil?

    course.save!
    return course

  end
end
