ARG TARGET_PLATFORM=linux/amd64
ARG IMAGE_TAG=latest

FROM --platform=${TARGET_PLATFORM} redis:${IMAGE_TAG}

COPY redis.conf /usr/local/etc/redis/redis.conf

WORKDIR /data

EXPOSE 6379

CMD ["redis-server", "/usr/local/etc/redis/redis.conf"]
