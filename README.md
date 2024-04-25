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
- [Docker](https://www.docker.com/products/docker-desktop/)
- A MySQL database to act as a database for the service (see the Database Structure section).
- SMTP server for sending emails. This only concerns the password reset feature.

## Installation

- Install Docker
- Make sure you have a MySQL database ready for this system to use.
- Clone the repository: `git clone https://github.com/cdlib/pid`
- Replace the `.env.example` file with a `.env` file and fill in the necessary values.
- Replace `./config/*.yml.example` files with `*.yml` versions. Note how some fields reference environment variables in the .env file.