# PID Service (a.k.a PURL Service)

###BUILD STATUS:
[![Build Status](https://secure.travis-ci.org/cdlib/pid.png)](http://travis-ci.org/cdlib/pid)
[![Dependency Status](https://gemnasium.com/cdlib/pid.png)](https://gemnasium.com/cdlib/pid)

## Overview

The PID service is a redesign of OCLC's old PURL service which became the Zephiera PURLZ service which eventually was absorbed into the Callimachus Project.

A PID is a Persistent URL that can be used in lieu of URLs that you think may change over time. 

It provides you with the ability to protect your systems and users from HTTP 404 errors caused by changes to URLs that are managed by organizations outside of your control.

The PID system consists of two core functional areas:
- **Link Resolver** - A component that translates calls to a PID into the URL behind it. For example a user clicks on my.domain.edu/PID/1234 and the system redirects the user to some.site.org/path/to/file.html

- **Administration Site** - A series of administration pages that allow you to search for PIDs, create/mint PIDs, update the URLs they point to, and manage users who can maintain PIDs.

## When and Why would I use a PID?
 
You have a URL, some.site.org/path/to/file.html, to an article on a third party system and you would like to provide to your users on several different sites.

You are concerned that the third party might move the article at some point in the future. To prevent this situation from causing you heartache, you decide to generate/mint a PURL, my.domain.edu/PID/1234, and associate it with some.site.org/path/to/file.html. You then place the link to the PURL on your sites in all of the places where you would normally have placed the third party URL.

When the third party moves that article to some.site.org/new/path/to/same/file.html, you can simply update the link associated with your PID rather than having to worry about finding all of the places you placed the link on your sites.

## Dependencies

- Ruby >= 1.9.3
- Rubygems >= 2.0.7 and the Bundler gem
- Redis >= 2.6.16 (link resolver uses in-memory Redis)
- MySql DB to host the administration data
- SQLite for testing
- PhantomJS for testing 

## Installation

- Make sure all of the dependencies are installed
- Make sure you have a MySQL database ready for this system to use (see below for SQL to create the DB)
- > git clone https://github.com/cdlib/pid
- Replace all of the ./config/*.yml.example with *.yml versions. The best way to do this is to create a local folder outside of the project and place your versions of the configuration files there. Then create symbolic links to those files in the ./config directory within this project. This will prevent your files from being changed when updating the project from GitHub.
- > gem install bundler
- > gem install extensions
- > bundle install

## Updating
- If you did not place your versions of the yml config files into an external folder, you will want to back them up. then in the project folder run > git stash
- > git pull origin master
- Move your configuration files back into the project folder if necessary

## Usage
- Start Redis: > rake redis:start
- Stop Redis: > rake redis:stop
- Start the PURL Service > thin -R config.ru start -p [port]
- To seed the MySQL DB with legacy data (See below for details) > thin -R config.ru -e 'seeded' start
- Test everything > rake test
- Test the non-UI components > rake test_app
- Test the UI only > rake test_client

## Database Structure

TODO: Generate SQL statements to create tables and indexes  
  
###Seeding The Database With Legacy Data:
  **WARNING:** This process will wipe out all of the data in your tables if the flush_tables value is true in the /db/seed.yml file !!! 

  For seeding the database, the system is expecting your legacy csv data files to be found at ~/pid_legacy_db/ (this location can be modified 
  within the /db/seed.yml). The system is expecting 4 separate files, one for Groups, one for Users, and one for PIDs, and one for the 
  Maintainers/Managers of Groups. The files should be comma, not tab delimited!!
  
  The PIDs file should include all historical information about a PID on separate lines. the lines should appear in chronological order: 
  For example:
* id,url,modified_at,username,change_category, notes
* 123,http://www.google.com/,2000-04-19 13:43:10,jdoe,BATCH,null
* 123,http://www.google.com/search?q=ruby+format+date&oq=ruby+format+date,2000-10-18 14:33:25,jdoe,USER_ENTERED,Testing
* 123,http://www.google.com/search?q=ruby+config,2007-11-14 15:03:03,jdoe,USER_ENTERED,null

  In the example above, the first line will create the initial PID record, and all subsequent lines will 'revise' the PID. Each revision will
  update the url, change_category, modified_at, and deactivated (should the URL be null) status of the PID record, and then add itself to the
  PidVersion recordset.
  
  You may include any combination of available attributes (see their respective .rb files) for each object in your csv files as long as you 
  include all of the required attributes. For example if User.affiliation is not important to you, you may exclude it from the users.csv.
  
  The first line of the each csv file should contain the attribute names, and those names should match the property names in the model.rb. 
  For example:
* id,name,description
* ADMIN,Administrators,Institution's administrators
      
  When referencing groups or users within a csv file, use user_id/group_id as the csv headers when you want the actual id value and 
  user/group as the csv header when you want the entire model. The maintainers.csv is expecting the entire user and group objects.
  
  A template for each of the 4 csv files can be found in /db/templates/
  
  This import process will skip records that have issues loading and will notify you of the item's id and the nature of the issue. You can then 
  either manually add these records through the GUI or rerun the seed process after correcting the problems. Make sure you comment out the 
  flush! lines at the top of /db/seed.rb to prevent the seed process from deleting all of the records added during the initial seed!! 
  
