FROM majid7221/debian:buster

ARG DEBIAN_FRONTEND=noninteractive

# Install ruby
RUN set -ex \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
      ruby \
      libgeoip1 \
      mmdb-bin \
    && rm -rf /var/lib/{apt,dpkg,cache,log}/ /tmp/* /var/tmp/*

# Install fluentd
ENV FLUENTD_VERSION 1.9.2
ENV JEMALLOC_VERSION 4.5.0
RUN set -eux \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
      build-essential \
      autoconf \
      make \
      g++ \
      libc-dev \
      ruby-dev \
      libgeoip-dev \
      libncursesw5-dev \
      libmaxminddb-dev \ 
    && echo 'gem: --no-document' >> /etc/gemrc \
    && gem install oj -v 3.8.1 \
    && gem install json -v 2.3.0 \
    && gem install async-http -v 0.50.0 \
    && gem install ext_monitor -v 0.1.2 \
    && gem install fluentd -v $FLUENTD_VERSION \
    && gem install fluent-plugin-elasticsearch \
    && gem install fluent-plugin-geoip \
    && gem install fluent-plugin-record-modifier \
    && dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')" \
    && gosu nobody true \
    && wget -O /tmp/jemalloc-$JEMALLOC_VERSION.tar.bz2 http://github.com/jemalloc/jemalloc/releases/download/$JEMALLOC_VERSION/jemalloc-$JEMALLOC_VERSION.tar.bz2 \
    && cd /tmp \
    && tar -xjf jemalloc-$JEMALLOC_VERSION.tar.bz2 && cd jemalloc-$JEMALLOC_VERSION/ \
    && ./configure && make \
    && mv lib/libjemalloc.so.2 /usr/lib \
    && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
      build-essential \
      autoconf \
      make \
      g++ \
      libc-dev \
      ruby-dev \
      libgeoip-dev \
      libncursesw5-dev \
      libmaxminddb-dev \ 
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /tmp/* /var/tmp/* /usr/lib/ruby/gems/*/cache/*.gem

RUN set -ex \
    && groupadd -r fluent \
    && useradd -r -g fluent fluent \
    && mkdir -p /fluentd/log \
    && mkdir -p /fluentd/etc /fluentd/plugins \
    && chown -R fluent /fluentd \
    && chgrp -R fluent /fluentd

COPY entrypoint.sh /bin/

# /fluentd/etc/fluentd.conf
ENV FLUENTD_CONF="fluentd.conf"

ENV LD_PRELOAD="/usr/lib/libjemalloc.so.2"

EXPOSE 24224 5140

USER fluent
ENTRYPOINT ["/bin/entrypoint.sh"]

CMD ["fluentd","-c","/fluentd/etc/${FLUENTD_CONF}"]
