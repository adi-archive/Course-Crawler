# Load libraries 
require 'rubygems'
require 'bundler/setup'
Bundler.require(:default)
require 'dm-core'
require 'dm-migrations'
require 'open-uri'

# Load configuration
APP_CONFIG = YAML::load( File.open( "config.yaml" ) )

# Load models
 Dir.glob(File.dirname(__FILE__) + '/models/*') {|file| require file}

# Configure DataMapper ORM
DataMapper::Logger.new($stdout, :debug) if APP_CONFIG["debug_mode"]

system "rake db:create"
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

# Crawl!
Section.crawl
Course.crawl
