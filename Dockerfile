# ============================================================
# グローバル ARG（全ステージで参照可能）
# ============================================================
ARG OPENSSL_VERSION=3.6.2

# ============================================================
# Stage 1: OpenSSL ソース取得
#   - nginx_builder が --with-openssl で内部ビルドする
# ============================================================
FROM ubuntu:latest AS openssl_builder
ARG OPENSSL_VERSION
ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /app
RUN --mount=type=cache,sharing=locked,target=/var/lib/apt/lists \
    --mount=type=cache,sharing=locked,target=/var/cache/apt/archives \
    apt update \
 && apt install -y --no-install-recommends git ca-certificates \
 && git clone --recursive --branch openssl-${OPENSSL_VERSION} --depth 1 https://github.com/openssl/openssl


# ============================================================
# Stage 2: GeoIP2 モジュール取得
# ============================================================
FROM ubuntu:latest AS geoip2_builder
ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /app
RUN --mount=type=cache,sharing=locked,target=/var/lib/apt/lists \
    --mount=type=cache,sharing=locked,target=/var/cache/apt/archives \
    apt update \
 && apt install -y --no-install-recommends git ca-certificates \
 && git clone --recursive https://github.com/leev/ngx_http_geoip2_module


# ============================================================
# Stage 3: brotli ビルド
# ============================================================
FROM ubuntu:latest AS brotli_builder
ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /app
RUN --mount=type=cache,sharing=locked,target=/var/lib/apt/lists \
    --mount=type=cache,sharing=locked,target=/var/cache/apt/archives \
    apt update \
 && apt install -y --no-install-recommends \
    build-essential git ca-certificates cmake \
 && git clone --recurse-submodules -j8 https://github.com/google/ngx_brotli \
 && cd ngx_brotli/deps/brotli \
 && mkdir out && cd out \
 && cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_C_FLAGS="-Ofast -m64 -march=native -mtune=native -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections" \
    -DCMAKE_CXX_FLAGS="-Ofast -m64 -march=native -mtune=native -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections" \
    -DCMAKE_INSTALL_PREFIX=./installed \
    .. \
 && cmake --build . --config Release --target brotlienc


# ============================================================
# Stage 4: njs ビルド
# ============================================================
FROM ubuntu:latest AS njs_builder
ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /app
RUN --mount=type=cache,sharing=locked,target=/var/lib/apt/lists \
    --mount=type=cache,sharing=locked,target=/var/cache/apt/archives \
    apt update \
 && apt install -y --no-install-recommends \
    build-essential ca-certificates git \
    libpcre2-dev libedit-dev \
 && git clone https://github.com/nginx/njs \
 && cd njs \
 && ./configure \
 && make \
 && make njs


# ============================================================
# Stage 5: DH パラメータ生成
# ============================================================
FROM ubuntu:latest AS dhparam_builder
ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /app
RUN --mount=type=cache,sharing=locked,target=/var/lib/apt/lists \
    --mount=type=cache,sharing=locked,target=/var/cache/apt/archives \
    apt update \
 && apt install -y --no-install-recommends build-essential ca-certificates openssl curl \
 && echo openssl dhparam -out dhparam.pem 4096 \
 && curl -L https://ssl-config.mozilla.org/ffdhe4096.txt > dhparam.pem \
 && openssl rand -out quic_host_key 16


# ============================================================
# Stage 6: nginx ビルド
#   - OpenSSL はソースツリー（openssl_builder の clone 済みソース）を渡す
#   - --with-openssl で nginx が内部ビルドする
#   - --cc-opt / --ld-opt は openssl_builder のビルド済みヘッダ/ライブラリを指す
# ============================================================
FROM ubuntu:latest AS nginx_builder
ENV DEBIAN_FRONTEND=noninteractive
COPY --from=geoip2_builder /app/ngx_http_geoip2_module /app/ngx_http_geoip2_module
COPY --from=brotli_builder /app/ngx_brotli                /app/ngx_brotli
COPY --from=openssl_builder /app/openssl                  /app/openssl
COPY --from=njs_builder /app/njs                          /app/njs
COPY ./app/nginx.conf    /app/nginx.conf
COPY ./app/modules.conf  /app/modules.conf
COPY ./app/modules.d     /app/modules.d
COPY ./app/conf.d        /app/conf.d
WORKDIR /app
ARG NGINX_USER=www-data
RUN --mount=type=cache,sharing=locked,target=/var/lib/apt/lists \
    --mount=type=cache,sharing=locked,target=/var/cache/apt/archives \
    apt update \
 && apt install -y --no-install-recommends \
    build-essential git ca-certificates mercurial \
    libpcre2-dev zlib1g-dev \
    libxslt1-dev libxslt1.1 \
    libcrypt-dev \
 && apt install -y --no-install-recommends \
    libmaxminddb-dev libmaxminddb0 mmdb-bin \
 && hg clone http://freenginx.org/hg/nginx \
 && cd nginx \
 && auto/configure \
    --user=$NGINX_USER \
    --group=$NGINX_USER \
    --prefix=/usr/share/nginx \
    --sbin-path=/usr/sbin/nginx \
    --conf-path=/etc/nginx/nginx.conf \
    --http-log-path=/var/log/nginx/access.log \
    --error-log-path=/var/log/nginx/error.log \
    --lock-path=/var/lock/nginx.lock \
    --pid-path=/run/nginx.pid \
    --modules-path=/usr/lib/nginx/modules \
    --http-client-body-temp-path=/var/lib/nginx/body \
    --http-fastcgi-temp-path=/var/lib/nginx/fastcgi \
    --http-proxy-temp-path=/var/lib/nginx/proxy \
    --http-scgi-temp-path=/var/lib/nginx/scgi \
    --http-uwsgi-temp-path=/var/lib/nginx/uwsgi \
    --with-debug \
    --with-compat \
    --with-pcre-jit \
    --with-http_ssl_module \
    --with-http_stub_status_module \
    --with-http_realip_module \
    --with-http_auth_request_module \
    --with-http_v2_module \
    --with-http_slice_module \
    --with-threads \
    --with-http_addition_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_sub_module \
    --with-stream \
    --with-stream_ssl_module \
    --with-http_v3_module \
    --with-openssl=../openssl \
    --with-openssl-opt="enable-ktls" \
    --add-dynamic-module=../ngx_brotli \
    --add-dynamic-module=../ngx_http_geoip2_module \
    --add-dynamic-module=../njs/nginx \
 && make -j$(nproc) \
 && make install \
 && install -m 0755 -d /etc/nginx/ssl \
 && install -m 0755 -d /etc/nginx/njs \
 && install -m 0755 -d /etc/nginx/conf.d \
 && install -m 0755 -d /etc/nginx/vhosts.d \
 && install -m 0755 -d /etc/nginx/modules.d \
 && install -m 0755 -d /var/nginx/vhosts \
 && install -m 0755 -d /var/nginx/well-known/html \
 && install -m 0644 /app/nginx.conf     /etc/nginx/nginx.conf \
 && install -m 0644 /app/modules.conf   /etc/nginx/modules.conf \
 && install -m 0644 /app/modules.d/*.conf /etc/nginx/modules.d/ \
 && install -m 0644 /app/conf.d/*.conf  /etc/nginx/conf.d/ \
 && touch /etc/nginx/conf.d/blank.conf /etc/nginx/vhosts.d/blank.conf \
 && chgrp $NGINX_USER /etc/nginx \
 && chmod 750 /etc/nginx


# ============================================================
# Stage 7: 実行イメージ
#   - njs の .so も nginx_builder から持ってくる
# ============================================================
FROM ubuntu:latest AS nginx_executor
ENV DEBIAN_FRONTEND=noninteractive
COPY ./app/entrypoint.sh                    /app/entrypoint.sh
COPY --from=nginx_builder /usr/sbin/nginx   /usr/sbin/nginx
COPY --from=nginx_builder /usr/share/nginx  /usr/share/nginx
COPY --from=nginx_builder /usr/lib/nginx    /usr/lib/nginx
COPY --from=nginx_builder /etc/nginx        /etc/nginx
COPY --from=nginx_builder /var/nginx        /var/nginx
COPY --from=dhparam_builder /app/dhparam.pem    /etc/nginx/ssl/dhparam.pem
COPY --from=dhparam_builder /app/quic_host_key  /etc/nginx/ssl/quic_host_key
# njs バイナリ（CLI）が必要なら追加
COPY --from=njs_builder /app/njs/build/njs  /usr/local/bin/njs
WORKDIR /app
RUN --mount=type=cache,sharing=locked,target=/var/lib/apt/lists \
    --mount=type=cache,sharing=locked,target=/var/cache/apt/archives \
    apt update \
 && apt install -y --no-install-recommends \
    ca-certificates libxslt1.1 libedit2 \
 && apt install -y --no-install-recommends \
    libmaxminddb0 mmdb-bin \
 && mkdir -p /var/lib/nginx /var/log/nginx \
 && chmod 700 /var/lib/nginx /var/log/nginx \
 && chmod 755 /app/entrypoint.sh \
 && ln -sf /proc/self/fd/1 /var/log/nginx/access.log \
 && ln -sf /proc/self/fd/2 /var/log/nginx/error.log
CMD ["/app/entrypoint.sh"]
