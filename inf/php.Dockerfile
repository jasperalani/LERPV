FROM php:7.3-fpm

ARG DEBIAN_FRONTEND=noninteractive
#SG: Removed this as PHP was failing to build and doesn't appear to materially affect the built container
#RUN sysctl -w net.ipv6.conf.all.disable_ipv6=1 && sysctl -w net.ipv6.conf.default.disable_ipv6=1
RUN apt-get update && \
    apt-get install -y libzip-dev zlib1g-dev libicu-dev g++ git curl \
    libxml2-dev libldap2-dev iproute2 vim-doc iputils-ping nmap libpng-dev \
    sendmail libc-client-dev libkrb5-dev \
    && rm -r /var/lib/apt/lists/*

COPY ./config/php/php.ini /usr/local/etc/php/php.ini

RUN docker-php-ext-configure intl
RUN docker-php-ext-configure imap --with-kerberos --with-imap-ssl
RUN docker-php-ext-configure ldap --with-libdir=lib/x86_64-linux-gnu/
RUN CFLAGS="-I/usr/src/php" docker-php-ext-install bcmath gd intl imap json ldap mbstring mysqli xmlreader zip
RUN pecl install -o -f xdebug redis && rm -rf /tmp/pear && docker-php-ext-enable xdebug redis
RUN mkdir -p /run/php/
RUN sed -i 's/^listen = .*/listen = 0.0.0.0:9000/' /usr/local/etc/php-fpm.d/www.conf
RUN sed -i 's/;php_admin_flag\[log_errors\]/php_admin_flag[log_errors]/' /usr/local/etc/php-fpm.d/www.conf
RUN sed -i 's/;php_admin_value\[error_log\]/php_admin_value[error_log]/' /usr/local/etc/php-fpm.d/www.conf
RUN touch /var/log/fpm-php.www.log
RUN chmod 666 /var/log/fpm-php.www.log
RUN touch /var/log/xdebug.log
RUN chmod 666 /var/log/xdebug.log

EXPOSE 9000

CMD ["/usr/local/sbin/php-fpm", "-F"]