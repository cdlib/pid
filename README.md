Name:     PID Service prototype a.k.a. Shortcake
Authors:  scollett, briley
Date:     7/12/13

This is a prototype of a revised version of the PURL Server. It implements a core subset of the PURL spec, basically it's a tiny URL service with versioning. It is written in the ruby language and runs on the Sinatra platform (http://www.sinatrarb.com/). It uses SQLite as its primary database and Redis as the cached data store for PID redirects.

BUILD STATUS:
[![Build Status](https://secure.travis-ci.org/cdlib/shortcake.png)](http://travis-ci.org/cdlib/shortcake)

DEPENDENCIES:
  It is recommended that you install the following gems to get the application running on
  your system with bundler: bundler install

  Redis and SQLite must be installed.


REDIS:
  To start redis:
    rake redis:start
    
  To stop redis:
    rake redis:stop
    
RUNNING:
  To run the application (without legacy data):
    thin -R config.ru start
    
  To run the application (with a subset of your legacy system's data. See below for details):
    thin -R config.ru -e 'seeded' start

TESTING:    
  To run the tests:
    rake test
	
  To read all TODO, FIXME, and OPTIMIZE comments:
    rake notes 
	

SOURCE:
  The source code is managed by Git and is located at:
    https://github.com/cdlib/shortcake


NOTES:
  Make sure that all tests pass before you commit any changes to the git repo!
	
	
SEEDING THE DATABASE WITH LEGACY DATA:
  WARNING: This process will wipe out all of the data in your tables!!! If you would like to retain the data already in the system, comment out
           the flush! lines at the top of the /db/seed.rb file.

  For seeding the database, the system is expecting your legacy csv data files to be found at ~/pid_legacy_db/ (this location can be modified at
  the top of /db/seed.rb). The system is expecting 3 separate files, one for Groups, one for Users, and one for PIDs.
  
  You may include any combination of available attributes (see their respective .rb files) for each object in your csv files as long as you 
  include all of the required attributes. For example if User.affiliation is not important to you, you may exclude it from the users.csv.
  
  The first row of the each csv file should contain the attribute names. For example:
  			id,name,description
  		  	ADMIN,Administrators,Institution's administrators
			
  A template for each of the 3 csv files can be found in /db/templates/
  				
  This import process will skip records that have issues loading and will notify you of the item's id and the nature of the issue. You can then 
  either manually add these records through the GUI or rerun the seed process after correcting the problems. Make sure you comment out the 
  flush! lines at the top of /db/seed.rb to prevent the seed process from deleting all of the records added during the initial seed!! 
