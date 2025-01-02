FROM ubuntu:latest AS geoip2_builder
ENV DEBIAN_FRONTEND noninteractive
ENV LS_COLORS di=01;36
WORKDIR /app
#RUN --mount=type=cache,target=/var/lib/apt/lists --mount=type=cache,target=/var/cache/apt/archives \
# apt update \
RUN apt update \
 && apt install -y --no-install-recommends git ca-certificates  \
 && git clone --recursive https://github.com/leev/ngx_http_geoip2_module.git


FROM ubuntu:latest AS brotli_builder
ENV DEBIAN_FRONTEND noninteractive
ENV LS_COLORS di=01;36
WORKDIR /app
#RUN --mount=type=cache,target=/var/lib/apt/lists --mount=type=cache,target=/var/cache/apt/archives \
# apt update \
RUN apt update \
 && apt install -y --no-install-recommends build-essential git ca-certificates cmake \
 && echo ">>> build brotli" \
 && git clone --recurse-submodules -j8 https://github.com/google/ngx_brotli \
 && cd ngx_brotli/deps/brotli \
 && mkdir out && cd out \
 && cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DCMAKE_C_FLAGS="-Ofast -m64 -march=native -mtune=native -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections" -DCMAKE_CXX_FLAGS="-Ofast -m64 -march=native -mtune=native -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections" -DCMAKE_INSTALL_PREFIX=./installed .. \
 && cmake --build . --config Release --target brotlienc \
 && cd ../../../../


FROM ubuntu:latest AS openssl_builder
ENV DEBIAN_FRONTEND noninteractive
ENV LS_COLORS di=01;36
WORKDIR /app
#RUN --mount=type=cache,target=/var/lib/apt/lists --mount=type=cache,target=/var/cache/apt/archives \
# apt update \
RUN apt update \
 && apt install -y --no-install-recommends git ca-certificates  \
 && git clone --recursive https://github.com/openssl/openssl 



FROM ubuntu:latest AS njs_builder
ENV DEBIAN_FRONTEND noninteractive
ENV LS_COLORS di=01;36
WORKDIR /app
#RUN --mount=type=cache,target=/var/lib/apt/lists --mount=type=cache,target=/var/cache/apt/archives \
# apt update \
RUN apt update \
 && apt install -y --no-install-recommends  build-essential ca-certificates mercurial git libpcre2-dev libpcre3-dev libedit-dev \
# && hg clone http://hg.nginx.org/njs \
 && git clone https://github.com/nginx/njs \
 && cd njs \
 && ./configure \
 && make \
 && make njs \
 && cd ../

FROM ubuntu:latest AS dhparam_builder
ENV DEBIAN_FRONTEND noninteractive
ENV LS_COLORS di=01;36
WORKDIR /app
#RUN --mount=type=cache,target=/var/lib/apt/lists --mount=type=cache,target=/var/cache/apt/archives \
# apt update \
RUN apt update \
 && apt install -y --no-install-recommends  build-essential ca-certificates openssl \
 && openssl dhparam -out dhparam.pem 4096

FROM ubuntu:latest AS nginx_builder
ENV DEBIAN_FRONTEND noninteractive
ENV LS_COLORS di=01;36
COPY --from=geoip2_builder /app/ngx_http_geoip2_module /app/ngx_http_geoip2_module
COPY --from=brotli_builder /app/ngx_brotli /app/ngx_brotli
COPY --from=openssl_builder /app/openssl /app/openssl
COPY --from=njs_builder /app/njs /app/njs
COPY ./app/nginx.conf /app/nginx.conf
COPY ./app/modules.conf /app/modules.conf
COPY ./app/modules.d /app/modules.d
COPY ./app/conf.d /app/conf.d
WORKDIR /app
ARG NGINX_USER=www-data
RUN --mount=type=cache,target=/var/lib/apt/lists --mount=type=cache,target=/var/cache/apt/archives \
 apt update \
 && apt install -y --no-install-recommends build-essential git ca-certificates mercurial libpcre2-dev libpcre3-dev zlib1g-dev libxslt1-dev libxslt1.1 \
 && apt install -y --no-install-recommends software-properties-common gpg-agent \
 && add-apt-repository ppa:maxmind/ppa \
 && apt update \
 && apt install -y --no-install-recommends libmaxminddb-dev libmaxminddb0 mmdb-bin \
 && echo ">>> build nginx" \
 && hg clone http://freenginx.org/hg/nginx \
 && cd nginx  \
 && auto/configure   --user=$NGINX_USER --group=$NGINX_USER  --prefix=/usr/share/nginx   --sbin-path=/usr/sbin/nginx   --conf-path=/etc/nginx/nginx.conf   --http-log-path=/var/log/nginx/access.log   --error-log-path=/var/log/nginx/error.log   --lock-path=/var/lock/nginx.lock   --pid-path=/run/nginx.pid   --modules-path=/usr/lib/nginx/modules   --http-client-body-temp-path=/var/lib/nginx/body   --http-fastcgi-temp-path=/var/lib/nginx/fastcgi   --http-proxy-temp-path=/var/lib/nginx/proxy   --http-scgi-temp-path=/var/lib/nginx/scgi   --http-uwsgi-temp-path=/var/lib/nginx/uwsgi   --with-debug   --with-compat   --with-pcre-jit   --http-uwsgi-temp-path=/var/lib/nginx/uwsgi   --with-debug   --with-compat   --with-pcre-jit   --with-http_ssl_module   --with-http_stub_status_module   --with-http_realip_module   --with-http_auth_request_module   --with-http_v2_module   --with-http_slice_module   --with-threads   --with-http_addition_module   --with-http_gunzip_module   --with-http_gzip_static_module    --with-http_sub_module    --with-stream_ssl_module   --add-dynamic-module=../ngx_brotli --add-dynamic-module=../njs/nginx  --add-dynamic-module=../ngx_http_geoip2_module --with-stream  --with-http_v3_module --with-openssl=../openssl --with-openssl-opt="enable-ktls"  --with-cc-opt="-I../openssl/build/include"   --with-ld-opt="-L../openssl/build/lib" \
 && make \
 && make install \
 && install -m 0755 -d /etc/nginx/ssl \
 && install -m 0755 -d /etc/nginx/njs \
 && install -m 0755 -d /etc/nginx/conf.d \
 && install -m 0755 -d /etc/nginx/vhosts.d \
 && install -m 0755 -d /etc/nginx/modules.d \
 && install -m 0755 -d /var/nginx/vhosts \
 && install -m 0755 -d /var/nginx/well-known/html \
 && install -m 0644 /app/nginx.conf /etc/nginx/nginx.conf \
 && install -m 0644 /app/modules.conf /etc/nginx/modules.conf \
 && install -m 0644 /app/modules.d/*.conf /etc/nginx/modules.d/ \
 && install -m 0644 /app/conf.d/*.conf /etc/nginx/conf.d/ \
 && touch /etc/nginx/conf.d/blank.conf /etc/nginx/vhosts.d/blank.conf \
 && chgrp $NGINX_USER /etc/nginx \
 && chmod 750 /etc/nginx \
 && cd ../


FROM ubuntu:latest AS nginx_executor
ENV DEBIAN_FRONTEND noninteractive
ENV LS_COLORS di=01;36
COPY ./app/entrypoint.sh /app/entrypoint.sh
COPY --from=njs_builder   /app/njs/build/njs /usr/bin/njs
COPY --from=nginx_builder /usr/sbin/nginx /usr/sbin/nginx
COPY --from=nginx_builder /usr/share/nginx /usr/share/nginx
COPY --from=nginx_builder /usr/lib/nginx /usr/lib/nginx
COPY --from=nginx_builder /etc/nginx /etc/nginx
COPY --from=nginx_builder /var/nginx /var/nginx
COPY --from=dhparam_builder   /app/dhparam.pem /etc/nginx/ssl/dhparam.pem
WORKDIR /app
RUN --mount=type=cache,target=/var/lib/apt/lists --mount=type=cache,target=/var/cache/apt/archives \
 apt update \
 && apt install -y --no-install-recommends ca-certificates libpcre3 libxslt1.1 libedit2 \
 && apt install -y --no-install-recommends software-properties-common gpg-agent \
 && add-apt-repository ppa:maxmind/ppa \
 && apt update \
 && apt install -y --no-install-recommends libmaxminddb-dev libmaxminddb0 mmdb-bin \
 && echo ">>> install nginx" \
 && mkdir /var/lib/nginx /var/log/nginx \
 && chmod 700 /var/lib/nginx /var/log/nginx \
 && chmod 755 /app/entrypoint.sh \
 && cd /var/log/nginx \
 && ln -s /proc/self/fd/1 access.log \
 && ln -s /proc/self/fd/2 error.log  
#CMD [ "/usr/sbin/nginx", "-g", "daemon off;" ]
CMD [ "/app/entrypoint.sh" ]
