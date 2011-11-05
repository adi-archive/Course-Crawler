require 'open-uri'

class Subject
  include DataMapper::Resource
  property :id, Serial
  property :abbreviation, String, :length => 256
  property :title, String, :length => 256

  has n, :sections

  BASE_URL = "http://www.columbia.edu/cu/bulletin/uwb/subj/"
  MAX_CONCURRENCY = 100


  # Return array of all subject urls
  def self.get_subject_urls
    doc = Nokogiri::HTML(open(BASE_URL))

    subject_urls = []
    elements = doc.css('a')
    elements.slice(5, elements.size).each_with_index do |element, index|
      subject_urls << "#{BASE_URL}#{element.content}"
    end

    subject_urls.uniq
  end

  # Return array of all section urls
  def self.get_section_urls(subject_urls)
    hydra = Typhoeus::Hydra.new(:max_concurrency => MAX_CONCURRENCY)

    subject_requests = []

    # built http requests for each subject
    subject_urls.each do |subject_url|
      request = self.section_urls_request(subject_url)
      subject_requests << request
      hydra.queue request
    end

    # run the request queue in parallel (blocking)
    hydra.run

    # merge each subject's section urls array 
    section_urls = []
    subject_requests.each do |subject_req|
      section_urls += subject_req.handled_response
    end

    # return section urls hash
    section_urls.uniq
  end

  # Crawls subject html page for subject's section urls
  def self.section_urls_request(subject_url) 
    request = Typhoeus::Request.new(subject_url)
    request.on_complete do |response|
      doc = Nokogiri::HTML(response.body)

      section_urls = []
      section_elements = doc.css('a')
      section_elements.each do |a|
        if a.content =~ /[A-Z0-9]+-[0-9]+-[0-9]+/
          section_urls << "#{subject_url}#{a.content}"
        end
      end

      # Return array of section urls with duplicates removed
      section_urls
    end

    # return the request object for post-response processing
    request
  end

end
