ARG TARGET_PLATFORM=linux/amd64
ARG IMAGE_TAG=3.3.7-slim-bullseye

FROM --platform=${TARGET_PLATFORM} ruby:${IMAGE_TAG} AS base

RUN apt-get update -qq \
    && apt-get install -y \
        default-libmysqlclient-dev \
    && apt-get upgrade -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

FROM base AS dependencies

RUN apt-get update -qq \
    && apt-get install -y \
        build-essential \
    && apt-get upgrade -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Gemfile Gemfile.lock ./

RUN bundle config set --local without 'test' && \
    bundle install

FROM --platform=$TARGET_PLATFORM base AS final

COPY --from=dependencies /usr/local/bundle /usr/local/bundle

WORKDIR /app

COPY . .

EXPOSE 80

CMD ["bundle", "exec", "puma", "-p", "80"]
