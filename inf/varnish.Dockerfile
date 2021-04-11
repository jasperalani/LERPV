FROM varnish

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get install -y varnish nginx curl iproute2 vim iputils-ping nmap procps

COPY ./config/varnish/default.vcl /etc/varnish/default.vcl
