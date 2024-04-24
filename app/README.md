# PID Service (a.k.a PURL Service)

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

The whole application, including dependencies like Redis, is Dockerized and can be run as a container. Libraries and packages are managed by Bundler; please refer to the Gemfile and Gemfile.lock files for more information. Aside from those, here is a list of things you need to run the application on your machine:
- Docker
- A MySQL database to act as a database for the service (see the Database Structure section).
- SMTP server for sending emails. This only concerns the password reset feature.

## Installation

- Install Docker
- Make sure you have a MySQL database ready for this system to use.
- Clone the repository: `git clone https://github.com/cdlib/pid`
- Replace the `.env.example` file with a `.env` file and fill in the necessary values.
- Replace `./config/*.yml.example` files with `*.yml` versions. Note how some fields reference environment variables in the .env file.


## Running the Application

- Navigate to the root directory of the project and run `docker-compose up --build` to start the application. This will start the Redis container as well as the application container, but only after making sure the tests pass. You can modify the `docker-compose.yml` file to skip the tests.
- If you rebuild the Redis container (or build it for the first time), you need to initialize it with data from the database. Follow the steps below.
  1. Open a new terminal.
  1. Run `docker ps` and find the application container (by default the image name is `pid-app`). Note the name of the container (this is not necessarily the same as the image name, and by default the name should be `pid-app-1`), this is the value for `<container_name>` in the next step.
  1. Run `docker exec -it <container_name> /bin/bash` to enter the application container.
  1. Run `ruby ruby_scripts/synchronize_redis.rb` to synchronize the Redis cache with the database. This can take a few minutes, depending on the size of your database. Note that this process is for initializing Redis to agree with an existing database; as you mint and modify the database via the application interface Redis should be updated automatically.
- There's another script to checks for duplicate URLs. This is not as crucial to the functioning of the application as Redis, but you can run it by following the steps above, except replace the command in the final step with `ruby ruby_scripts/detect_duplicate_urls.rb`.
- As you update the application, rebuild by running `docker-compose up --build`.
- To start the application without rebuilding, run `docker-compose up`.
- To tear down, run `docker-compose down`.
- Once the containers are up and running, you can access the web page for the service at `http://localhost:<app_port>`. You can modify `<app_port>` in the `.env` file, but by default it's 80.

## Running Tests

- Tests are automatically run with `docker-compose up --build`. However, if you wish to run tests manually, navigate to the root directory and run `docker-compose build test`.
- If you want to run individual tests, you can replace the line `RUN ["rake", "test"]` in `Dockerfile.test` before running the manual command above. Below are some examples; you can refer to the Ruby and Rake documentation for more information. 
  - `RUN ["rake", "test_client", "TEST=test/client/test_user_views.rb"]`
  - `RUN ["ruby", "-I", "test", "test/integration/test_pid_controller.rb", "-n", "test_post_pid"]`

## Database Structure

TODO: Generate SQL statements to create tables and indexes.

Please refer to the schema file `/app/db/schema.rb` to see the structure of the database. The schema file was generated by Active Record while connected to the actual database for the service. It is currently used to initialize the database for testing with SQLite, so it should be a good reference, though unfortunately it doesn't include the indexes and constraints. Please contact lam.pham@ucop.edu for more information.
