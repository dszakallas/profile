FROM bretfisher/jekyll:stable-20231215-2119a31
COPY src/Gemfile src/Gemfile.lock .
RUN bundle install
