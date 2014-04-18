##Name:     PID Service prototype a.k.a. Shortcake

This is a prototype of a revised version of the PURL Server. It implements a core subset of the PURL spec, basically it's a tiny URL service with versioning. It is written in the ruby language and runs on the Sinatra platform (http://www.sinatrarb.com/). It uses SQLite as its primary database and Redis as the cached data store for PID redirects.

###BUILD STATUS:
[![Build Status](https://secure.travis-ci.org/cdlib/shortcake.png)](http://travis-ci.org/cdlib/shortcake)
[![Dependency Status](https://gemnasium.com/cdlib/shortcake.png)](https://gemnasium.com/cdlib/shortcake)

####SOURCE:
  The source code is managed by Git and is located at: [https://github.com/cdlib/shortcake](https://github.com/cdlib/shortcake)

###DEPENDENCIES:
  Redis and SQLite must be installed!
  You also need a mysql DB.

###INSTALLATION:
  Following the instructions outlined in Redmine:
      https://redmine.cdlib.org/wiki/purl-service/Purl_20

####REDIS Commands:
  To start redis: `rake redis:start`
  To stop redis: `rake redis:stop`
    
####Running The Application:
  To run the application: `thin -R config.ru start`
    
  To run the application and seed the DB with a subset of your legacy system's data (See below for details): `thin -R config.ru -e 'seeded' start`

####Testing Commands:    
  To run the all tests: `rake test`
  To run only the controller, model, and redis tests: `rake tes_app`
  To run only the client side tests: `rake test_client`
  
  To read all TODO, FIXME, and OPTIMIZE comments: `rake notes`
  
  
####Seeding The Database With Legacy Data:
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
  
