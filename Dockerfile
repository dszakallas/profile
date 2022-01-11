FROM jekyll/jekyll:4.0
COPY src/Gemfile src/Gemfile.lock .
RUN bundle install

