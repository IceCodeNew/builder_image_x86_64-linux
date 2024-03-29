FROM mirror.gcr.io/library/ubuntu:jammy AS base
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ARG DEBIAN_FRONTEND=noninteractive
# https://api.github.com/repos/slimm609/checksec.sh/releases/latest
ARG checksec_latest_tag_name='2.4.0'
# https://api.github.com/repos/IceCodeNew/myrc/commits?per_page=1&path=.bashrc
ARG bashrc_latest_commit_hash='6f332268abdbb7ef6c264a84691127778e3c6ef2'
# https://api.github.com/repos/Kitware/CMake/tags?per_page=100
ARG cmake_latest_tag_name='v3.19.1'
# https://api.github.com/repos/ninja-build/ninja/releases/latest
ARG ninja_latest_tag_name='v1.10.2'
# https://api.github.com/repos/sabotage-linux/netbsd-curses/releases/latest
# ARG netbsd_curses_tag_name='0.3.1'
# https://api.github.com/repos/sabotage-linux/gettext-tiny/releases/latest
# ARG gettext_tiny_tag_name='0.3.2'
ARG image_build_date='2020-12-04'
# http://bugs.python.org/issue19846
# > At the moment, setting "LANG=C" on a Linux system *fundamentally breaks Python 3*, and that's not OK.
ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PKG_CONFIG=/usr/bin/pkgconf \
    PATH=/root/.local/bin:$PATH \
    PKG_CONFIG_PATH=/usr/lib64/pkgconfig:$PKG_CONFIG_PATH
RUN mkdir -p '/etc/dpkg/dpkg.cfg.d' '/etc/apt/apt.conf.d' \
    && echo 'force-unsafe-io' > '/etc/dpkg/dpkg.cfg.d/docker-apt-speedup' \
    && echo 'Acquire::Languages "none";' > '/etc/apt/apt.conf.d/docker-no-languages' \
    && echo -e 'Acquire::GzipIndexes "true";\nAcquire::CompressionTypes::Order:: "gz";' > '/etc/apt/apt.conf.d/docker-gzip-indexes' \
    && apt-get update -qq && apt-get full-upgrade -y \
    && apt-get -y --no-install-recommends install \
    ca-certificates curl gpg gpg-agent \
    && curl -sSL 'https://apt.llvm.org/llvm-snapshot.gpg.key' | apt-key add - \
    && echo 'deb http://apt.llvm.org/jammy/ llvm-toolchain-jammy main' > /etc/apt/sources.list.d/llvm.list \
    && apt-get update -qq \
    && apt-get -y --no-install-recommends install \
    binutils build-essential cmake coreutils dos2unix file git libarchive-tools libedit-dev libltdl-dev libncurses-dev libsystemd-dev libtool-bin netbase ninja-build pkgconf python3-pip python3-venv util-linux \
    clang lld \
    && apt-get -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false purge \
    && apt-get clean \
    && rm -rf /var/cache/apt/* \
    && rm -rf /var/lib/apt/lists/* \
    && update-alternatives --install /usr/local/bin/pkg-config pkg-config /usr/bin/pkgconf 100 \
    && update-alternatives --auto pkg-config \
    && curl -sSLR4q --retry 5 --retry-delay 10 --retry-max-time 60 --connect-timeout 60 -m 600 -o '/root/.bashrc' "https://raw.githubusercontent.com/IceCodeNew/myrc/${bashrc_latest_commit_hash}/.bashrc" \
    && curl -sSLR4q --retry 5 --retry-delay 10 --retry-max-time 60 --connect-timeout 60 -m 600 -o '/usr/bin/checksec' "https://raw.githubusercontent.com/slimm609/checksec.sh/${checksec_latest_tag_name}/checksec" \
    && chmod +x '/usr/bin/checksec' \
    # && unset -f curl \
    # && eval "$(sed -E '/^curl\(\)/!d' /root/.bashrc)" \
    && source '/root/.bashrc' \
    && ( tmp_dir=$(mktemp -d) && pushd "$tmp_dir" || exit 1 && curl -sSL --compressed -o "cmake-${cmake_latest_tag_name#v}-Linux-x86_64.sh" "https://github.com/Kitware/CMake/releases/download/${cmake_latest_tag_name}/cmake-${cmake_latest_tag_name#v}-Linux-x86_64.sh" && bash "cmake-${cmake_latest_tag_name#v}-Linux-x86_64.sh" --skip-license --exclude-subdir --prefix=/usr && rm -rf "cmake-${cmake_latest_tag_name#v}-Linux-x86_64.sh" '/usr/bin/cmake-gui' '/usr/bin/ccmake' '/usr/bin/ctest' '/usr/share/cmake-3.16' && popd || exit 1 && dirs -c ) \
    && ( tmp_dir=$(mktemp -d) && pushd "$tmp_dir" || exit 1 && curl -sSL "https://github.com/ninja-build/ninja/releases/download/${ninja_latest_tag_name}/ninja-linux.zip" | bsdtar -xf- && $(type -P install) -pvD './ninja' '/usr/bin/' && popd || exit 1 && /bin/rm -rf "$tmp_dir" && dirs -c ) \
    && rm -rf "$HOME/.cache/pip" \
    && rm -rf /var/log/* \
    && mkdir '/build_root' \
    && mkdir '/usr/local/doc' \
    && mkdir '/usr/local/share/doc'
    ### https://github.com/sabotage-linux/netbsd-curses
    # && curl -sSL "http://ftp.barfooze.de/pub/sabotage/tarballs/netbsd-curses-${netbsd_curses_tag_name}.tar.xz" | bsdtar -xf- \
    # && ( cd "/netbsd-curses-${netbsd_curses_tag_name}" || exit 1; make CFLAGS="$CFLAGS -fPIC" PREFIX=/usr -j "$(nproc)" all install ) \
    # && rm -rf "/netbsd-curses-${netbsd_curses_tag_name}" \
    ### https://github.com/sabotage-linux/gettext-tiny
    # && curl -sSL "http://ftp.barfooze.de/pub/sabotage/tarballs/gettext-tiny-${gettext_tiny_tag_name}.tar.xz" | bsdtar -xf- \
    # && ( cd "/gettext-tiny-${gettext_tiny_tag_name}" || exit 1; make CFLAGS="$CFLAGS -fPIC" PREFIX=/usr -j "$(nproc)" all install ) \
    # && rm -rf "/gettext-tiny-${gettext_tiny_tag_name}"

FROM base AS mold
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# https://api.github.com/repos/rui314/mold/releases/latest
ARG mold_latest_tag_name='v2.4.0'
RUN curl --retry 5 --retry-delay 10 --retry-max-time 60 -fsSL "https://github.com/rui314/mold/releases/download/${mold_latest_tag_name}/mold-${mold_latest_tag_name#v}-x86_64-linux.tar.gz" | bsdtar -xf- --strip-components 1 -C /usr \
    && update-alternatives --install /usr/bin/ld ld /usr/bin/ld.mold 100 \
    && update-alternatives --auto ld

FROM mold AS parallel
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
## curl -sSL "https://ftpmirror.gnu.org/parallel/" | tr -d '\r\n\t' | grep -Po '(?<=parallel-)[0-9]+(?=\.tar\.bz2)' | sort -Vr | head -n 1
ARG parallel_version='20210122'
WORKDIR /build_root
RUN source '/root/.bashrc' \
    && gpg --import <(curl -sSLR "https://ftpmirror.gnu.org/gnu-keyring.gpg") > /dev/null 2>&1 \
    && curl -sSLROJ "https://ftpmirror.gnu.org/parallel/parallel-${parallel_version}.tar.bz2" \
    && curl -sSLROJ "https://ftpmirror.gnu.org/parallel/parallel-${parallel_version}.tar.bz2.sig" \
    && gpg --verify "parallel-${parallel_version}.tar.bz2.sig" \
    && bsdtar -xf "parallel-${parallel_version}.tar.bz2" \
    && rm "parallel-${parallel_version}.tar.bz2" "parallel-${parallel_version}.tar.bz2.sig" \
    && pushd "parallel-${parallel_version}" || exit 1 \
    && ./configure --prefix=/usr \
    && make -j"$(nproc)" \
    && make install \
    && popd || exit 1 \
    && rm -rf -- "/build_root/parallel-${parallel_version}" \
    && dirs -c \
    && mkdir -p "$HOME/.parallel" \
    && touch "$HOME/.parallel/will-cite"

FROM parallel AS zlib-ng
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# https://api.github.com/repos/zlib-ng/zlib-ng/releases/latest
ARG zlib_ng_latest_tag_name='2.0.2'
WORKDIR /build_root
RUN source '/root/.bashrc' \
    && git_clone --branch "${zlib_ng_latest_tag_name#v}" "https://github.com/zlib-ng/zlib-ng.git" \
    && pushd zlib-ng || exit 1 \
    && prefix=/usr ./configure --static --zlib-compat \
    && make -j"$(nproc)" \
    && make -j"$(nproc)" test \
    # && mkdir -p '/build_root/.zlib-ng/lib/pkgconfig' \
    # && mkdir -p '/build_root/.zlib-ng/share/man' \
    && make install \
    && popd || exit 1 \
    && rm -rf -- '/build_root/zlib-ng' \
    && dirs -c

FROM zlib-ng AS openssl
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# https://api.github.com/repos/openssl/openssl/commits?per_page=1&sha=OpenSSL_1_1_1-stable
ARG openssl_latest_commit_hash='9d5580612887b0c37016e7b65707e8e9dc27f4bb'
## curl -sSL 'https://raw.githubusercontent.com/openssl/openssl/OpenSSL_1_1_1-stable/README' | grep -Eo '1.1.1.*'
ARG openssl_latest_tag_name='1.1.1i-dev'
WORKDIR /build_root
RUN source '/root/.bashrc' \
    && mkdir "openssl-${openssl_latest_tag_name}" \
    && curl -sSL "https://github.com/openssl/openssl/archive/OpenSSL_1_1_1-stable.tar.gz" | bsdtar -xf- --strip-components 1 -C "openssl-${openssl_latest_tag_name}" \
    && pushd "/build_root/openssl-${openssl_latest_tag_name}" || exit 1 \
    && chmod +x ./config \
    && ./config --prefix=/usr --release no-deprecated no-tests no-shared no-dtls1-method no-tls1_1-method no-md4 no-sm2 no-sm3 no-sm4 no-rc2 no-rc4 threads CFLAGS="$CFLAGS -fPIC" CXXFLAGS="$CXXFLAGS -fPIC" \
    && make -j "$(nproc)" CFLAGS="$CFLAGS -fPIE -Wl,-pie" CXXFLAGS="$CXXFLAGS -fPIE -Wl,-pie" \
    # && mkdir -p '/usr/lib/pkgconfig' \
    # && mkdir -p '/usr/lib/engines-1.1' \
    && make install_sw \
    && popd || exit 1 \
    && rm -rf -- "/build_root/openssl-${openssl_latest_tag_name}" \
    && dirs -c

FROM openssl AS pcre2
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
## https://api.github.com/repos/PhilipHazel/pcre2/releases/latest
ARG pcre2_version='pcre2-10.39'
WORKDIR /build_root
RUN source '/root/.bashrc' \
    && mkdir "$pcre2_version" \
    && curl -sSL "https://github.com/PhilipHazel/pcre2/releases/latest/download/${pcre2_version}.tar.bz2" | bsdtar -xf- --strip-components 1 -C "$pcre2_version" \
    && pushd "/build_root/${pcre2_version}" || exit 1 \
    && ./configure --prefix=/usr --enable-jit --enable-jit-sealloc \
    && make -j "$(nproc)" CFLAGS="$CFLAGS -mshstk -fPIC" \
    && make install \
    && popd || exit 1 \
    && rm -rf -- "/build_root/${pcre2_version}" \
    && dirs -c
