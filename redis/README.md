## Redis

The Redis container is to be launched simultatneously with the application container. The logic for this is already handled in the `docker-compose.yml` file.

Redis is used to cache data from the database to speed up the application. The `synchronize_redis.rb` script is used to initialize the Redis cache with data from the database; it should be run after the Redis container is built for the first time or rebuilt. Instructions for this are in the `README.md` file in the `/app` directory. Redis should be updated automatically as you modify the database via the application's interface.