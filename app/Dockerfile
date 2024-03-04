FROM ruby:3.2.2 AS base

WORKDIR /app

RUN apt-get update -qq && apt-get upgrade -y

COPY Gemfile Gemfile.lock ./

RUN bundle config set --local without 'test' && \
    bundle install

FROM ruby:3.2.2-bookworm AS final

WORKDIR /app

COPY --from=base /usr/local/bundle /usr/local/bundle

COPY . .

EXPOSE 80

CMD ["bundle", "exec", "puma", "-p", "80"]

FROM ruby:3.2.2 AS test

WORKDIR /app

# Download dependencies for testing
RUN apt-get update -qq && \
    apt-get install -y \
        libsqlite3-dev \
        sqlite3 \
        wget \
        gnupg \
        unzip \
        libnss3 \
        libatk-bridge2.0-0 \
        libatk1.0-0 \
        libatspi2.0-0 \
        libgtk-3-0 \
        libx11-xcb1 \
        libdrm2 \
        libgbm1 \
        libasound2 \
        libde265-0 \
        libgnutls30 \
        linux-libc-dev && \
    apt-get -y upgrade && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Refer to this site for version info: https://googlechromelabs.github.io/chrome-for-testing/#stable
ARG CHROME_URL=https://edgedl.me.gvt1.com/edgedl/chrome/chrome-for-testing/119.0.6045.105/linux64/chrome-linux64.zip
ARG CHROMEDRIVER_URL=https://edgedl.me.gvt1.com/edgedl/chrome/chrome-for-testing/119.0.6045.105/linux64/chromedriver-linux64.zip

# Set the installation directories
ENV CHROME_INSTALL_DIR=/opt/google/chrome
ENV CHROMEDRIVER_INSTALL_DIR=/usr/local/bin

# Download and install Chrome
RUN mkdir -p $CHROME_INSTALL_DIR \
    && curl -SL $CHROME_URL -o chrome-linux64.zip \
    && unzip chrome-linux64.zip -d $CHROME_INSTALL_DIR \
    && rm chrome-linux64.zip

# Download and install Chromedriver
RUN mkdir -p $CHROMEDRIVER_INSTALL_DIR \
    && curl -SL $CHROMEDRIVER_URL -o chromedriver-linux64.zip \
    && unzip chromedriver-linux64.zip -d $CHROMEDRIVER_INSTALL_DIR \
    && rm chromedriver-linux64.zip

# Set the PATH to include Chrome and Chromedriver
ENV PATH=$CHROME_INSTALL_DIR/chrome-linux64:$CHROMEDRIVER_INSTALL_DIR/chromedriver-linux64:$PATH

COPY Gemfile Gemfile.lock ./

RUN bundle install --with test

COPY . .

RUN ["rake", "test"]