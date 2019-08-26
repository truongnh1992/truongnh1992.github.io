FROM jekyll/builder

COPY . /usr/src/app
VOLUME /usr/src/app
EXPOSE 4000

WORKDIR /usr/src/app


RUN bundle install


CMD ["bundle", "exec", "jekyll", "serve"]
