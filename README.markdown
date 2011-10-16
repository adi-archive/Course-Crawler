Course Crawler
============

This crawl program successfully aggregated Columbia course and related
information as of Sunday, February 20, 2011. Columbia's data formats are
subject to change, and I can not guarantee that this program will be
compatible with future formats. 

Questions, comments, and concerns should be directed at:
Ryan Bubinski. ryanbubinski <at> gmail <dot> com.


Dependencies
------------

Ruby 1.8.7>=
MySQL 5.0>=


Installation and Setup
------------

Before beginning, make sure you have Ruby 1.8.7 or later and MySQL 5.0 or
later installed.

- Copy "config.yaml.default" to "config.yaml"
- Complete the following fields in config.yaml
  database:
    adapter: mysql
    host: [localhost]
    username: [db_username]  
    password: [db_user_passwd]
    database: [db_name]
- run `gem install bundler`
- run `bundle install`


Crawling
------------

Once you've set up the application, run the app.rb file in the root directory
to begin the crawling process.


Exporting data
------------

Data is stored in a local database, which can be exported to a text file
in SQL format using the command:

`rake db:export`

The result is stored in the local directory in a file named "data.sql"
