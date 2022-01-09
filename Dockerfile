FROM jekyll/jekyll:4.0
COPY Gemfile Gemfile.lock .
RUN bundle install

