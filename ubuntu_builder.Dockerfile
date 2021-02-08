FROM quay.io/icecodenew/ubuntu:latest AS base
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ARG DEBIAN_FRONTEND=noninteractive
# https://api.github.com/repos/slimm609/checksec.sh/releases/latest
ARG checksec_latest_tag_name='2.4.0'
# https://api.github.com/repos/IceCodeNew/myrc/commits?per_page=1&path=.bashrc
ARG bashrc_latest_commit_hash='6f332268abdbb7ef6c264a84691127778e3c6ef2'
# https://api.github.com/repos/Kitware/CMake/releases/latest
ARG cmake_latest_tag_name='v3.19.1'
# https://api.github.com/repos/ninja-build/ninja/releases/latest
ARG ninja_latest_tag_name='v1.10.2'
# https://api.github.com/repos/sabotage-linux/netbsd-curses/releases/latest
# ARG netbsd_curses_tag_name='0.3.1'
# https://api.github.com/repos/sabotage-linux/gettext-tiny/releases/latest
# ARG gettext_tiny_tag_name='0.3.2'
ARG image_build_date='2020-12-04'
ENV PKG_CONFIG=/usr/bin/pkgconf \
    PATH=/usr/lib/llvm-12/bin:$PATH
RUN apt-get update && apt-get -y --no-install-recommends install \
    apt-utils autoconf automake binutils build-essential ca-certificates checkinstall checksec cmake coreutils curl dos2unix file gettext git gpg gpg-agent libarchive-tools libedit-dev libltdl-dev libncurses-dev libsystemd-dev libtool-bin locales netbase ninja-build pkgconf util-linux \
    && apt-get -y full-upgrade \
    && apt-get -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false purge \
    && curl -L 'https://apt.llvm.org/llvm-snapshot.gpg.key' | apt-key add - \
    && echo 'deb http://apt.llvm.org/focal/ llvm-toolchain-focal-12 main' > /etc/apt/sources.list.d/llvm.stable.list \
    && apt-get update && apt-get -y --install-recommends install \
    clang-12 lld-12 libc++-12-dev libc++abi-12-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && sed -i '/en_US.UTF-8/s/^# //' /etc/locale.gen \
    && dpkg-reconfigure --frontend=noninteractive locales \
    && update-locale LANG=en_US.UTF-8 \
    # && update-ca-certificates \
    # && for i in {1..2}; do checksec --update; done \
    && update-alternatives --install /usr/local/bin/ld ld /usr/lib/llvm-12/bin/lld 100 \
    && update-alternatives --auto ld \
    && curl -sSLR4q --retry 5 --retry-delay 10 --retry-max-time 60 --connect-timeout 60 -m 600 -o '/root/.bashrc' "https://raw.githubusercontent.com/IceCodeNew/myrc/${bashrc_latest_commit_hash}/.bashrc" \
    # && unset -f curl \
    # && eval "$(sed -E '/^curl\(\)/!d' /root/.bashrc)" \
    && source '/root/.bashrc' \
    && ( cd /usr || exit 1; curl -OJ --compressed "https://github.com/Kitware/CMake/releases/download/${cmake_latest_tag_name}/cmake-${cmake_latest_tag_name#v}-Linux-x86_64.sh" && bash "cmake-${cmake_latest_tag_name#v}-Linux-x86_64.sh" --skip-license && rm -f -- "/usr/cmake-${cmake_latest_tag_name#v}-Linux-x86_64.sh" '/usr/bin/cmake-gui' '/usr/bin/ccmake' '/usr/bin/ctest'; rm -rf -- /usr/share/cmake-3.16; true ) \
    && ( tmp_dir=$(mktemp -d) && pushd "$tmp_dir" || exit 1 && curl -sS "https://github.com/ninja-build/ninja/releases/download/${ninja_latest_tag_name}/ninja-linux.zip" | bsdtar -xf- && $(type -P install) -pvD './ninja' '/usr/bin/' && popd || exit 1 && /bin/rm -rf "$tmp_dir" && dirs -c ) \
    && mkdir '/build_root' \
    && mkdir '/usr/local/doc'
    ### https://github.com/sabotage-linux/netbsd-curses
    # && curl -sS --compressed "http://ftp.barfooze.de/pub/sabotage/tarballs/netbsd-curses-${netbsd_curses_tag_name}.tar.xz" | bsdtar -xf- \
    # && ( cd "/netbsd-curses-${netbsd_curses_tag_name}" || exit 1; checkinstall -y --nodoc --pkgversion="$netbsd_curses_tag_name" --dpkgflags="--force-overwrite" make CFLAGS="$CFLAGS -fPIC" PREFIX=/usr -j "$(nproc)" all install ) \
    # && rm -rf "/netbsd-curses-${netbsd_curses_tag_name}" \
    ### https://github.com/sabotage-linux/gettext-tiny
    # && curl -sS --compressed "http://ftp.barfooze.de/pub/sabotage/tarballs/gettext-tiny-${gettext_tiny_tag_name}.tar.xz" | bsdtar -xf- \
    # && ( cd "/gettext-tiny-${gettext_tiny_tag_name}" || exit 1; checkinstall -y --nodoc --pkgversion="$gettext_tiny_tag_name" --dpkgflags="--force-overwrite" make CFLAGS="$CFLAGS -fPIC" PREFIX=/usr -j "$(nproc)" all install ) \
    # && rm -rf "/gettext-tiny-${gettext_tiny_tag_name}"

FROM base AS zlib
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# https://api.github.com/repos/madler/zlib/tags
ARG zlib_latest_tag_name='v1.2.11'
WORKDIR /build_root
RUN source '/root/.bashrc' \
    && mkdir zlib \
    && curl -sS "https://github.com/madler/zlib/archive/v1.2.11.tar.gz" | bsdtar -xf- -C zlib --strip-components 1 \
    && pushd zlib || exit 1 \
    && ./configure --prefix="/build_root/.zlib" --static \
    && make -j"$(nproc)" \
    && checkinstall -y --nodoc --pkgversion="${zlib_latest_tag_name#v}" \
    && popd || exit 1 \
    && rm -rf -- '/build_root/zlib' \
    && dirs -c

FROM zlib AS pcre2
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
## curl -sSL "https://ftp.pcre.org/pub/pcre/" | tr -d '\r\n\t' | grep -Po '(?<=pcre2-)[0-9]+\.[0-9]+(?=\.tar\.bz2)' | sort -ru | head -n 1
ARG pcre2_version='10.35'
WORKDIR /build_root
RUN source '/root/.bashrc' \
    && curl -sS --compressed "https://ftp.pcre.org/pub/pcre/pcre2-${pcre2_version}.tar.bz2" | bsdtar -xf- \
    && pushd "/build_root/pcre2-${pcre2_version}" || exit 1 \
    && ./configure --enable-jit --enable-jit-sealloc \
    && make -j "$(nproc)" CFLAGS="$CFLAGS -mshstk -fPIC" \
    && checkinstall -y --nodoc --pkgversion="$pcre2_version" \
    && popd || exit 1 \
    && rm -rf -- "/build_root/pcre2-${pcre2_version}" \
    && dirs -c

FROM pcre2 AS openssl
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# https://api.github.com/repos/openssl/openssl/commits?per_page=1&sha=OpenSSL_1_1_1-stable
ARG openssl_latest_commit_hash='9d5580612887b0c37016e7b65707e8e9dc27f4bb'
## curl -sSL 'https://raw.githubusercontent.com/openssl/openssl/OpenSSL_1_1_1-stable/README' | grep -Eo '1.1.1.*'
ARG openssl_latest_tag_name='1.1.1i-dev'
WORKDIR /build_root
RUN source '/root/.bashrc' \
    && mkdir "openssl-${openssl_latest_tag_name}" \
    && curl -sS --compressed "https://github.com/openssl/openssl/archive/OpenSSL_1_1_1-stable.tar.gz" | bsdtar -xf- --strip-components 1 -C "openssl-${openssl_latest_tag_name}" \
    && pushd "/build_root/openssl-${openssl_latest_tag_name}" || exit 1 \
    && chmod +x ./config \
    && ./config --prefix="/build_root/.openssl" --release no-deprecated no-tests no-shared no-dtls1-method no-tls1_1-method no-sm2 no-sm3 no-sm4 no-rc2 no-rc4 threads CFLAGS="$CFLAGS -fPIC" CXXFLAGS="$CXXFLAGS -fPIC" LDFLAGS='-fuse-ld=lld' \
    && make -j "$(nproc)" CFLAGS="$CFLAGS -fPIE -Wl,-pie" CXXFLAGS="$CXXFLAGS -fPIE -Wl,-pie" \
    && checkinstall -y --nodoc --pkgversion="$openssl_latest_tag_name" make install_sw \
    && popd || exit 1 \
    && rm -rf -- "/build_root/openssl-${openssl_latest_tag_name}" \
    && dirs -c
