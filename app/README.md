## Running the Application

- Make sure you have the repository cloned (`git clone https://github.com/cdlib/pid.git`).
- Navigate to the root directory of the project (where `docker-compose.yml` exists).
- Replace the `.env.example` file with a `.env` file and fill in the necessary values.
  > Generate a 64-character hex for the session secret. The SMTP stuff is optional.
- Replace `/app/config/*.yml.example` files with `*.yml` versions.
  > The `.example` files are primarily for reference, though they will be sufficient to get the app running; you can modify the values to implement your own configuration. Naturally, if you wish to connect to an external database, you may need to be on VPN.
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


## Running Tests

Assuming you've cloned the repository (`git clone https://github.com/cdlib/pid.git`), tests are automatically run with `docker-compose up --build`. To run tests manually:
- If you want to run all the tests, navigate to the root directory and run `docker-compose build test`.
- If you want to run individual tests, you can replace the line `RUN ["rake", "test"]` (which runs all the tests) in `Dockerfile.test` before running the command above. Below are some examples, you can refer to the Ruby and Rake documentation for more information.
  - `RUN ["rake", "test_client", "TEST=test/client/test_user_views.rb"]`
  - `RUN ["ruby", "-I", "test", "test/integration/test_pid_controller.rb", "-n", "test_post_pid"]`

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

## Developer Contacts

- Lam Pham (lam.pham@ucop.edu)
- Charlie Collett (charlie.collett@ucop.edu)