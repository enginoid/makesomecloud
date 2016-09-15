FROM hseeberger/scala-sbt

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    build-essential \
    python-dev \
 && apt-get clean \
 && rm -rf /usr/share/doc/* /tmp/* /var/tmp/*

COPY monorepo /monorepo
RUN cd /monorepo && ./pants --config-override=pants.ci.ini compile :: && rm -rf /monorepo
