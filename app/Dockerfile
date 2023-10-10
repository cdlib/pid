FROM ruby:2.1.5

# RUN apt-get update -qq && \
#     apt-get install -y \
#     build-essential \
#     chrpath \
#     libssl-dev \
#     libxft-dev \
#     libfreetype6 \
#     libfreetype6-dev \
#     libfontconfig1 \
#     libfontconfig1-dev \
#     wget \
#     && \
#     wget https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-2.1.1-linux-x86_64.tar.bz2 && \
#     tar xvjf phantomjs-2.1.1-linux-x86_64.tar.bz2 && \
#     mv phantomjs-2.1.1-linux-x86_64 /usr/local/share && \
#     ln -sf /usr/local/share/phantomjs-2.1.1-linux-x86_64/bin/phantomjs /usr/local/bin

WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock ./

RUN bundle install

COPY . .

EXPOSE 3000

CMD ["bundle", "exec", "thin", "-R", "config.ru", "start", "-p", "3000"]
