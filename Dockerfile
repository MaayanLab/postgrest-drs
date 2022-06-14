FROM postgrest/postgrest

USER root
RUN set -x \
  && apt-get -y update \
  && apt-get -y install nginx supervisor \
  && rm -rf /var/lib/apt/lists/*
ADD nginx.conf /etc/nginx/nginx.conf
ADD supervisord.conf /etc/supervisord.conf

CMD ["supervisord", "-n", "-c", "/etc/supervisord.conf"]
