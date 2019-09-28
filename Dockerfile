FROM alpine:3.9 as BUILDER

RUN apk --update --no-cache add build-base \
        git libtool autoconf automake gd-dev \
        php7-dev libpng-dev libjpeg-turbo-dev \
        freetype-dev libwebp-dev

RUN mkdir build && cd build  && \
    git clone https://github.com/LacquerLabs/libpuzzle.git

RUN cd /build/libpuzzle && \
    ./autogen.sh && ./configure && \
    make clean && make && make install

RUN cd /build/libpuzzle/php/libpuzzle && \
    phpize && \
    ./configure --with-libpuzzle && \
    make clean && make && make install

FROM alpine:3.9 as DEPLOY

# Load ash profile on launch
ENV ENV="/etc/profile"

# Set the timezone and PHP ini settings
ENV TIMEZONE=America/New_York \
    PHP_MEMORY_LIMIT=256M \
    MAX_UPLOAD=100M \
    PHP_MAX_FILE_UPLOAD=50 \
    PHP_MAX_POST=100M \
    PHP_MAX_EXECUTION_TIME=360

# Setup ash profile prompt and my old man alias
RUN mv /etc/profile.d/color_prompt /etc/profile.d/color_prompt.sh && \
    echo alias dir=\'ls -alh --color\' >> /etc/profile

# install nginx and php7-fpm
# setup and make the working directories
# setup timezone and delete the tzdata package
# add the www-data user
RUN apk --update --no-cache add nginx openssl dumb-init tzdata shadow \
    php7-fpm php7-json php7-gd php7-curl php7-dom php7-exif libgd \
    php7-iconv php7-imagick php7-json php7-mbstring php7-mysqli \
    php7-opcache php7-ctype php7-simplexml php7-xml php7-xmlreader && \
    mkdir -p /app /run/nginx /run/php7 && \
    cp /usr/share/zoneinfo/${TIMEZONE} /etc/localtime && \
    echo "${TIMEZONE}" > /etc/timezone && \
    apk del tzdata

# nginx:x:100:101:nginx:/var/lib/nginx:/sbin/nologin
# www-data:x:1001:82:Linux User,,,:/home/www-data:/bin/false


# Manually make some changes for the PHP.INI file
RUN sed -i "s|;*date.timezone =.*|date.timezone = ${TIMEZONE}|i" /etc/php7/php.ini && \
    sed -i "s|;*max_execution_time =.*|max_execution_time = ${PHP_MAX_EXECUTION_TIME}|i" /etc/php7/php.ini && \
    sed -i "s|;*memory_limit =.*|memory_limit = ${PHP_MEMORY_LIMIT}|i" /etc/php7/php.ini && \
    sed -i "s|;*upload_max_filesize =.*|upload_max_filesize = ${MAX_UPLOAD}|i" /etc/php7/php.ini && \
    sed -i "s|;*max_file_uploads =.*|max_file_uploads = ${PHP_MAX_FILE_UPLOAD}|i" /etc/php7/php.ini && \
    sed -i "s|;*post_max_size =.*|post_max_size = ${PHP_MAX_POST}|i" /etc/php7/php.ini && \
    sed -i "s|;*cgi.fix_pathinfo=.*|cgi.fix_pathinfo= 0|i" /etc/php7/php.ini && \
    sed -i "s|;*error_log = .*|error_log = \/proc\/self\/fd\/1|i" /etc/php7/php.ini

COPY --from=builder /usr/local/lib/libpuzzle* /usr/local/lib/
COPY --from=builder /usr/lib/php7/modules/libpuzzle.so /usr/lib/php7/modules/libpuzzle.so

# copy our config files over to the container
COPY ./configs /etc

# enable libpuzzle
RUN echo "extension=libpuzzle.so" > /etc/php7/conf.d/50_libpuzzle.ini

# setup our working directory
# copy over working code
WORKDIR /app
COPY ./code .

RUN groupmod -g 1001 www-data && \
    usermod -u 1001 -g 1001 -d /run/nginx nginx && \
    chown -R nginx:www-data /run/nginx /run/php7 /app && \
    chmod -R g+srwx /run/nginx /run/php7 /app && \
    apk del shadow

# Setup Volume for persistance
VOLUME /app

# expose our service port
EXPOSE 8080

STOPSIGNAL SIGTERM

USER nginx

# start with our PID 1 controller
ENTRYPOINT ["/usr/bin/dumb-init", "--"]

# what we use to start the container
CMD ["/bin/sh", "-c", "php-fpm7 --daemonize && nginx"]
