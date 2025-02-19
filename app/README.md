# APP README 

## Configuring

- Make sure you have the repository cloned (`git clone https://github.com/cdlib/pid.git`).
- Navigate to the root directory of the project (where `docker-compose.yml` exists).
- Replace the `.env.example` file with a `.env` file and fill in the necessary values.
  > Generate a 64-character hex for the session secret. The SMTP stuff is optional.
- Replace `/app/config/*.yml.example` files with `*.yml` versions.
  > The `.example` files are primarily for reference, though they will be sufficient to get the app running; you can modify the values to implement your own configuration. Naturally, if you wish to connect to an external database, you may need to be on VPN.

## Docker Installation
### Running the Appplication
- Using `docker-compose`:
  - Run `docker-compose up --build` to build and start the application.
    > This will build the Redis container as well as the application container, but only after making sure the tests pass. You can modify the `docker-compose.yml` file to skip the tests.
  - As you update the application, rebuild by running `docker-compose build`.
  - To start the application without or after rebuilding, run `docker-compose up`.
  - To tear down, run `docker-compose down`.
- Once the containers are up and running, you can access the web page for the service at `http://localhost:<app_port>`.
  > You can modify `<app_port>` in the `.env` file, but by default it's 80.
- If you rebuild the Redis container or build it for the first time, you will need to initialize it with data from the database. Follow the steps below.
  1. Open a new terminal.
  1. Run `docker ps` and find the application container (by default the image name is `pid-app`). Note the name of the container (this is not necessarily the same as the image name, and by default the name should be `pid-app-1`), this is the value for `<container_name>` in the next step.
  1. Run `docker exec -it <container_name> /bin/bash` to enter the application container.
  1. Run `ruby ruby_scripts/synchronize_redis.rb` to synchronize the Redis cache with the database. This can take a few minutes, depending on the size of your database. Note that this process is for initializing Redis to agree with an existing database; as you modify the database via the application's interface, Redis should be updated automatically.
- There's another script to checks for duplicate URLs. This is not as crucial to the functioning of the application as Redis, but you can run it by following the steps above, except replace the command in the final step with `ruby ruby_scripts/detect_duplicate_urls.rb`.


### Running Tests

Assuming you've cloned the repository (`git clone https://github.com/cdlib/pid.git`), tests are automatically run with `docker-compose up --build`. To run tests manually:
- If you want to run all the tests, navigate to the root directory and run `docker-compose build test`.
- If you want to run individual tests, you can replace the line `RUN ["rake", "test"]` (which runs all the tests) in `Dockerfile.test` before running the command above. Below are some examples, you can refer to the Ruby and Rake documentation for more information.
  - `RUN ["rake", "test_client", "TEST=test/client/test_user_views.rb"]`
  - `RUN ["ruby", "-I", "test", "test/integration/test_pid_controller.rb", "-n", "test_post_pid"]`

## Mac OS X Installation

These instructions assume you are working on a Mac with Homebrew installed.

1.  **Clone the Repository & Prepare Environment Files**
  
    `git clone https://github.com/cdlib/pid.git cd pid # 
    
    * Replace .env.example with your .env file and update values. 

    * Copy example and setup environment variables.
      > `cp .env.example .env`
    
      > **Note:** 
      >  - You will need access to a pid database locally or on a host.
      >  - You will need access to a redis in not using docker
      >  - For the session secret, generate a 64-character hexadecimal string (which represents 32 bytes): `openssl rand -hex 32`

2.  **Set Up Ruby Using rbenv**  
    Install rbenv via Homebrew if you haven't already:
    
    `brew install rbenv`
    
    Initialize rbenv (follow the instructions that appear to add it to your shell profile, e.g., in `~/.zshrc`):
  
    
    `rbenv init`
    
    Install Ruby 3.2.2 (or version in the Gemfile):
    
    `rbenv install 3.2.2`
    
    Then, in your project directory, set the local Ruby version:
    
    `cd path/to/pid/app rbenv local 3.2.2`
    
3.  **Install Bundler and Dependencies**  
    Install Bundler:

    `gem install bundler`
    
    `bundle install`
    
4.  **Install MySQL Client**  
    The application requires the MySQL client for the native `mysql2` gem. There may be an error during install. If so, install it with Homebrew:

    `brew install mysql-client`
    
    Because `mysql-client` is keg-only, add it to your PATH. Append this line to your shell profile (`~/.zshrc`):
    
    `echo 'export PATH="/opt/homebrew/opt/mysql-client/bin:$PATH"' >> ~/.zshrc`
    
    Then, reload your shell:
    
    `source ~/.zshrc`
    
    `export LDFLAGS="-L/opt/homebrew/opt/mysql-client/lib" export CPPFLAGS="-I/opt/homebrew/opt/mysql-client/include"`
    
5.  **Ensure zstd Is Installed**  
    (If it isn’t already installed, you can do so with:)

    `brew install zstd`
    
    Verify that its libraries are in `/opt/homebrew/opt/zstd/lib`.
    
6.  **Manually Install the mysql2 Gem**  
    The gemfile specifies a particular version (e.g., `0.5.6`). Install it manually using the proper flags to ensure it finds both MySQL and zstd libraries. Replace `0.5.6` with the version specified in your Gemfile.lock if different.
    `export LIBRARY_PATH="/opt/homebrew/opt/zstd/lib:$LIBRARY_PATH"`
    
    `gem install mysql2 --version 0.5.6 -- \   --with-mysql-config=/opt/homebrew/opt/mysql-client/bin/mysql_config \   --with-ldflags="-L/opt/homebrew/opt/zstd/lib" \   --with-cppflags="-I/opt/homebrew/opt/zstd/include"`
    
7.  **Run the Application or Tests**  
    
    `rake test`
    
    > Note: The unit tests should work without Redis or Mysql connection.
    
    or start the app:
    
    `ruby app.rb`

    > Note: Running the application requires Redis and Mysql connections.

8.  **Issues with Selenium ChromeUI tests**

    If you have issues with Selenium Chrome web tests you will need to install it.

    Install Google Chrome if not already on system.
     
    Install Chromedriver:
    
    `brew install --cask chromedriver`
    
    Verify the installation path:

    `which chromedriver`
    
    The expected path is typically `/opt/homebrew/bin/chromedriver`.
    

## Database Structure

TODO: Generate SQL statements to create tables and indexes.

MySQL Table Overview
- **Users** - All users of the system have an account. An account can be locked due to too many invalid logins.
- **Groups** - All of the user groupings
- **Maintainers** - A list of users who are allowed to manage a group. Currently, ALL users can maintain ALL groups.
- **Pids** - The core PID table
- **Pid_versions** - Historical copies of a PID. The Pids table stores the current version.
- **Interesteds** - Obsolete
- **Statistics** - A table that stores statistical information such as the number of Pids modified by month for each Group. This table is populated by a job that is kicked off by Cron each weekend.
- **Duplicate_url_reports** - A table that stores a list of duplicate URLs (i.e. PIDs that point to the same URL). This table is populated by a job that is kicked off by Cron each weekend.
- **Invalid_url_reports** - A table that stores a list of invalid URLs (i.e. Pinging the URL returns an HTTP >= 400 status code). This table is populated by a job that is kicked off by Cron each weekend.
- **Skip_checks** - A table that stores the domains of URLs were a contractually not allowed to run the invalid URLs check against

Please refer to the schema file `/app/db/schema.rb` to see the structure of the database. The schema file was generated by Active Record while connected to the actual database for the service. It is currently used to initialize the database for testing with SQLite, so it should be a good reference, though unfortunately it doesn't include the indexes and constraints. Please contact one of the developers for more information.