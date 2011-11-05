# Load libraries 
require 'rubygems'
require 'bundler/setup'
Bundler.require(:default)

# Load configuration
APP_CONFIG = YAML::load( File.open( "config.yaml" ) )

# Load models
 Dir.glob(File.dirname(__FILE__) + '/models/*') {|file| require file}

# Configure DataMapper ORM
DataMapper::Logger.new($stdout, :debug) if APP_CONFIG["debug_mode"]
DataMapper.setup(:default, {
    :adapter  => "mysql",
    :database => APP_CONFIG["database"]["database"],
    :username => APP_CONFIG["database"]["username"],
    :password => APP_CONFIG["database"]["password"],
    :host     => APP_CONFIG["database"]["host"]
  })

# Prepare database
DataMapper.finalize
DataMapper.auto_upgrade!
system "rake db:seed"

# Get subject urls
subject_urls = Subject.get_subject_urls
puts "Loaded subject urls"

# Get section urls from subject urls
section_urls = Subject.get_section_urls(subject_urls)
puts "Loaded section urls"

# Crawl sections
Section.crawl(section_urls)

# Crawl courses (urls from sections)
Course.crawl
