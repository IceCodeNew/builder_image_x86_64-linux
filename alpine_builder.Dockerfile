FROM quay.io/icecodenew/alpine:latest AS base
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]
# https://api.github.com/repos/slimm609/checksec.sh/releases/latest
ARG checksec_latest_tag_name='2.4.0'
# https://api.github.com/repos/rui314/mold/releases/latest
ARG mold_latest_tag_name='v1.1'
ARG image_build_date='2022-03-07'

# http://bugs.python.org/issue19846
# > At the moment, setting "LANG=C" on a Linux system *fundamentally breaks Python 3*, and that's not OK.
ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PKG_CONFIG=/usr/bin/pkgconf \
    PKG_CONFIG_PATH=/build_root/qbittorrent-build/lib/pkgconfig \
    # LDFLAGS='-fuse-ld=lld' \
    # CFLAGS='-O2 -pipe -D_FORTIFY_SOURCE=2 -fexceptions -fstack-clash-protection -fstack-protector-strong -g -grecord-gcc-switches -Wl,-z,noexecstack,-z,relro,-z,now,-z,defs -Wl,--icf=all' \
    # CXXFLAGS='-O2 -pipe -D_FORTIFY_SOURCE=2 -fexceptions -fstack-clash-protection -fstack-protector-strong -g -grecord-gcc-switches -Wl,-z,noexecstack,-z,relro,-z,now,-z,defs -Wl,--icf=all'
    CFLAGS='-O2 -pipe -D_FORTIFY_SOURCE=2 -fexceptions -fstack-clash-protection -fstack-protector-strong -g -grecord-gcc-switches -Wl,-z,noexecstack,-z,relro,-z,now,-z,defs' \
    CXXFLAGS='-O2 -pipe -D_FORTIFY_SOURCE=2 -fexceptions -fstack-clash-protection -fstack-protector-strong -g -grecord-gcc-switches -Wl,-z,noexecstack,-z,relro,-z,now,-z,defs'

RUN apk update; apk --no-progress --no-cache add \
    bash binutils build-base ca-certificates cmake coreutils curl dos2unix file git grep libarchive-tools linux-headers musl musl-dev musl-libintl musl-utils parallel pcre2-dev perl pkgconf samurai sed \
    #  dpkg \
    clang lld; \
    apk --no-progress --no-cache upgrade; \
    # apk --no-progress --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/testing/ add \
    # mold; \
    rm -rf /var/cache/apk/*; \
    # update-alternatives --install /usr/bin/ld ld /usr/bin/lld 100; \
    # update-alternatives --install /usr/bin/ld ld /usr/bin/mold 100; \
    # update-alternatives --auto ld; \
    unset -f curl; \
    eval 'curl() { /usr/bin/curl -fL --retry 5 --retry-delay 10 --retry-max-time 60 "$@"; }'; \
    curl -sS -o '/usr/bin/checksec' "https://raw.githubusercontent.com/slimm609/checksec.sh/${checksec_latest_tag_name:=master}/checksec"; \
    chmod +x '/usr/bin/checksec'; \
    sed -i 's!/bin/ash!/bin/bash!' /etc/passwd; \
    mkdir -p "$HOME/.parallel"; \
    touch "$HOME/.parallel/will-cite"

FROM base AS zlib-ng
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# https://api.github.com/repos/zlib-ng/zlib-ng/releases/latest
ARG zlib_ng_latest_tag_name='2.0.6'
ARG dockerfile_workdir=/build_root/zlib-ng
WORKDIR $dockerfile_workdir
RUN git clone -j "$(nproc)" --no-tags --shallow-submodules --recurse-submodules --depth 1 --single-branch --branch "${zlib_ng_latest_tag_name#v}" "https://github.com/zlib-ng/zlib-ng.git" . \
    && CFLAGS="$CFLAGS -fPIC" \
    && CXXFLAGS="$CXXFLAGS -fPIC" \
    && export CFLAGS CXXFLAGS \
    && prefix=/usr ./configure --static --zlib-compat \
    && make -j"$(nproc)" \
    && make -j"$(nproc)" test \
    && make install \
    && rm -rf -- "$dockerfile_workdir"

FROM zlib-ng AS openssl
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# https://api.github.com/repos/openssl/openssl/commits?per_page=1&sha=OpenSSL_1_1_1-stable
ARG openssl_latest_commit_hash='d3602088603605f39993f03781163df2decf85e3'
## curl -sSL 'https://raw.githubusercontent.com/openssl/openssl/OpenSSL_1_1_1-stable/README' | grep -Eo '1.1.1.*'
ARG openssl_latest_tag_name='1.1.1n-dev'
ARG dockerfile_workdir=/build_root/openssl
WORKDIR $dockerfile_workdir
RUN git clone -j "$(nproc)" --no-tags --shallow-submodules --recurse-submodules --depth 1 --single-branch --branch "OpenSSL_1_1_1-stable" "https://github.com/openssl/openssl.git" . \
    && CFLAGS="$CFLAGS -fPIC" \
    && CXXFLAGS="$CXXFLAGS -fPIC" \
    && LDFLAGS="$LDFLAGS -pie" \
    && export CFLAGS CXXFLAGS LDFLAGS \
    && chmod +x ./config \
    && ./config --prefix=/usr --release no-deprecated no-tests no-shared no-dtls1-method no-tls1_1-method no-sm2 no-sm3 no-sm4 no-rc2 no-rc4 threads \
    && make -j "$(nproc)" \
    && make install_sw \
    && rm -rf -- "$dockerfile_workdir"
