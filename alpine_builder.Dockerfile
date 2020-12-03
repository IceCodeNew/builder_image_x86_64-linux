FROM quay.io/icecodenew/alpine:edge AS base
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]
# https://api.github.com/repos/slimm609/checksec.sh/releases/latest
ARG checksec_latest_tag_name='2.4.0'
# https://api.github.com/repos/IceCodeNew/myrc/commits?per_page=1&path=.bashrc
ARG bashrc_latest_commit_hash='6f332268abdbb7ef6c264a84691127778e3c6ef2'
## curl -sSL "https://ftp.pcre.org/pub/pcre/" | tr -d '\r\n\t' | grep -Po '(?<=pcre2-)[0-9]+\.[0-9]+(?=\.tar\.bz2)' | sort -ru | head -n 1
ARG pcre2_version='10.35'
## curl -sSL 'https://raw.githubusercontent.com/openssl/openssl/OpenSSL_1_1_1-stable/README' | grep -Eo '1.1.1.*'
ARG openssl_latest_tag_name='1.1.1i-dev'
# https://api.github.com/repos/Kitware/CMake/releases/latest
ARG cmake_latest_tag_name='v3.19.1'
# https://api.github.com/repos/ninja-build/ninja/releases/latest
ARG ninja_latest_tag_name='v1.10.2'
# https://api.github.com/repos/sabotage-linux/netbsd-curses/releases/latest
ARG netbsd_curses_tag_name='0.3.1'
# https://api.github.com/repos/sabotage-linux/gettext-tiny/releases/latest
ARG gettext_tiny_tag_name='0.3.2'
RUN apk update; apk --no-progress --no-cache add \
    apk-tools autoconf automake bash binutils build-base ca-certificates clang-dev clang-static cmake coreutils curl dos2unix dpkg file gettext-tiny-dev git grep libarchive-tools libedit-dev libedit-static libtool linux-headers lld musl musl-dev musl-libintl musl-utils ncurses ncurses-dev ncurses-static openssl openssl-dev openssl-libs-static pcre2 pcre2-dev pcre2-tools perl pkgconf samurai util-linux; \
    apk --no-progress --no-cache upgrade; \
    rm -rf /var/cache/apk/*; \
    # update-alternatives --install /usr/local/bin/cc cc /usr/bin/clang 100; \
    # update-alternatives --install /usr/local/bin/c++ c++ /usr/bin/clang++ 100; \
    update-alternatives --install /usr/local/bin/ld ld /usr/bin/lld 100; \
    # update-alternatives --auto cc; \
    # update-alternatives --auto c++; \
    update-alternatives --auto ld; \
    curl -sSLR4q --retry 5 --retry-delay 10 --retry-max-time 60 -o '/root/.bashrc' "https://raw.githubusercontent.com/IceCodeNew/myrc/${bashrc_latest_commit_hash}/.bashrc"; \
    unset -f curl; \
    eval 'curl() { /usr/bin/curl -LRq --retry 5 --retry-delay 10 --retry-max-time 60 "$@"; }'; \
    curl -sS -o '/usr/bin/checksec' "https://raw.githubusercontent.com/slimm609/checksec.sh/${checksec_latest_tag_name}/checksec"; \
    chmod +x '/usr/bin/checksec'; \
    mkdir -p '/build_root'
