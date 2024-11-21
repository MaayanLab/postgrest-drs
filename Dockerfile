FROM ubuntu

USER root
RUN set -x \
  && apt-get -y update \
  && apt-get -y install nginx supervisor curl xz-utils \
  && rm -rf /var/lib/apt/lists/*

RUN set -x \
  && cd /bin && curl -L https://github.com/PostgREST/postgrest/releases/download/v12.2.3/postgrest-v12.2.3-linux-static-x64.tar.xz | tar xJf -

ADD nginx.conf /etc/nginx/nginx.conf
ADD supervisord.conf /etc/supervisord.conf

CMD ["supervisord", "-n", "-c", "/etc/supervisord.conf"]
