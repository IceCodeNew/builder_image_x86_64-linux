FROM quay.io/icecodenew/debian:oldstable-slim AS base
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
# https://api.github.com/repos/mesonbuild/meson/releases/latest
ARG meson_latest_tag_name='0.57.1'
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
    PATH=/usr/lib/llvm-12/bin:$PATH
RUN apt-get update && apt-get -y --no-install-recommends install \
    apt-transport-https apt-utils autoconf automake binutils build-essential ca-certificates checkinstall cmake coreutils curl dos2unix file gettext git gpg gpg-agent libarchive-tools libedit-dev libltdl-dev libncurses-dev libsystemd-dev libtool-bin libz-dev locales netbase ninja-build parallel pkgconf python3-pip util-linux \
    && mv /etc/apt/sources.list /etc/apt/sources.list.backup \
    # && echo -e 'deb http://deb.debian.org/debian oldstable main contrib non-free\ndeb http://security.debian.org/debian-security oldstable/updates main contrib non-free\ndeb http://deb.debian.org/debian oldstable-updates main contrib non-free\ndeb http://deb.debian.org/debian oldstable-backports main contrib non-free' > /etc/apt/sources.list \
    && echo -e 'deb http://deb.debian.org/debian oldstable main\ndeb http://security.debian.org/debian-security oldstable/updates main\ndeb http://deb.debian.org/debian oldstable-updates main\ndeb http://deb.debian.org/debian oldstable-backports main' > /etc/apt/sources.list \
    && apt-get update && apt-get -y full-upgrade \
    && apt-get -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false purge \
    && curl -sSL 'https://apt.llvm.org/llvm-snapshot.gpg.key' | apt-key add - \
    && echo 'deb http://apt.llvm.org/stretch/ llvm-toolchain-stretch-12 main' > /etc/apt/sources.list.d/llvm.stable.list \
    && apt-get update && apt-get -y --install-recommends install \
    clang-12 lld-12 libc++-12-dev libc++abi-12-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && sed -i '/en_US.UTF-8/s/^# //' /etc/locale.gen \
    && dpkg-reconfigure --frontend=noninteractive locales \
    && update-locale --reset LANG=C.UTF-8 LC_ALL=C.UTF-8 \
    && update-alternatives --install /usr/local/bin/ld ld /usr/lib/llvm-12/bin/ld.lld 100 \
    && update-alternatives --auto ld \
    && update-alternatives --install /usr/local/bin/pkg-config pkg-config /usr/bin/pkgconf 100 \
    && update-alternatives --auto pkg-config \
    && curl -sSLR4q --retry 5 --retry-delay 10 --retry-max-time 60 --connect-timeout 60 -m 600 -o '/root/.bashrc' "https://raw.githubusercontent.com/IceCodeNew/myrc/${bashrc_latest_commit_hash}/.bashrc" \
    && curl -sSLR4q --retry 5 --retry-delay 10 --retry-max-time 60 --connect-timeout 60 -m 600 -o '/usr/bin/checksec' "https://raw.githubusercontent.com/slimm609/checksec.sh/${checksec_latest_tag_name}/checksec" \
    && chmod +x '/usr/bin/checksec' \
    # && unset -f curl \
    # && eval "$(sed -E '/^curl\(\)/!d' /root/.bashrc)" \
    && sed -i -E 's/-O2 -pipe -D_FORTIFY_SOURCE=2 -fexceptions -fstack-clash-protection -fstack-protector-strong -g -grecord-gcc-switches -Wl,-z,noexecstack,-z,relro,-z,now,-z,defs -Wl,--icf=all/-O2 -pipe -D_FORTIFY_SOURCE=2 -fexceptions -fstack-protector-strong -g -grecord-gcc-switches -Wl,-z,noexecstack,-z,relro,-z,now,-z,defs -Wl,--icf=all/' '/root/.bashrc' \
    && sed -i -E 's/--no-tags //' '/root/.bashrc' \
    && source '/root/.bashrc' \
    && ( tmp_dir=$(mktemp -d) && pushd "$tmp_dir" || exit 1 && curl -sSLR -o "cmake-${cmake_latest_tag_name#v}-Linux-x86_64.sh" --compressed "https://github.com/Kitware/CMake/releases/download/${cmake_latest_tag_name}/cmake-${cmake_latest_tag_name#v}-Linux-x86_64.sh" && bash "cmake-${cmake_latest_tag_name#v}-Linux-x86_64.sh" --skip-license --exclude-subdir --prefix=/usr && rm -rf "cmake-${cmake_latest_tag_name#v}-Linux-x86_64.sh" '/usr/bin/cmake-gui' '/usr/bin/ccmake' '/usr/bin/ctest' '/usr/share/cmake-3.7' && popd || exit 1 && dirs -c ) \
    && ( tmp_dir=$(mktemp -d) && pushd "$tmp_dir" || exit 1 && curl -sSL --compressed "https://github.com/ninja-build/ninja/releases/download/${ninja_latest_tag_name}/ninja-linux.zip" | bsdtar -xf- && $(type -P install) -pvD './ninja' '/usr/bin/' && popd || exit 1 && /bin/rm -rf "$tmp_dir" && dirs -c ) \
    && python3 -m pip install -U pip \
    && python3 -m pip install -U pip setuptools wheel \
    && python3 -m pip install -U meson \
    && rm -rf "$HOME/.cache/pip" \
    && mkdir '/build_root' \
    && mkdir '/usr/local/doc' \
    && mkdir '/usr/local/share/doc'
    ### https://github.com/sabotage-linux/netbsd-curses
    # && curl -sS --compressed "http://ftp.barfooze.de/pub/sabotage/tarballs/netbsd-curses-${netbsd_curses_tag_name}.tar.xz" | bsdtar -xf- \
    # && ( cd "/netbsd-curses-${netbsd_curses_tag_name}" || exit 1; checkinstall -y --nodoc --pkgversion="$netbsd_curses_tag_name" --dpkgflags="--force-overwrite" make CFLAGS="$CFLAGS -fPIC" PREFIX=/usr -j "$(nproc)" all install ) \
    # && rm -rf "/netbsd-curses-${netbsd_curses_tag_name}" \
    ### https://github.com/sabotage-linux/gettext-tiny
    # && curl -sS --compressed "http://ftp.barfooze.de/pub/sabotage/tarballs/gettext-tiny-${gettext_tiny_tag_name}.tar.xz" | bsdtar -xf- \
    # && ( cd "/gettext-tiny-${gettext_tiny_tag_name}" || exit 1; checkinstall -y --nodoc --pkgversion="$gettext_tiny_tag_name" --dpkgflags="--force-overwrite" make CFLAGS="$CFLAGS -fPIC" PREFIX=/usr -j "$(nproc)" all install ) \
    # && rm -rf "/gettext-tiny-${gettext_tiny_tag_name}"

FROM base AS parallel
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
    && checkinstall -y --nodoc --pkgversion="$parallel_version" \
    && popd || exit 1 \
    && rm -rf -- "/build_root/parallel-${parallel_version}" \
    && dirs -c \
    && mkdir -p "$HOME/.parallel" \
    && touch "$HOME/.parallel/will-cite"

FROM parallel AS zlib-ng
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# https://api.github.com/repos/zlib-ng/zlib-ng/tags
ARG zlib_ng_latest_tag_name='v2.0.0-RC2'
# https://api.github.com/repos/zlib-ng/zlib-ng/commits?per_page=1
ARG zlib_ng_latest_commit_hash='4b68367d442111b92f2c5e562b107e9a8cce4e10'
WORKDIR /build_root
RUN source '/root/.bashrc' \
    && git_clone "https://github.com/zlib-ng/zlib-ng" \
    && pushd zlib-ng || exit 1 \
    && prefix="/build_root/.zlib-ng" ./configure --static --zlib-compat \
    && make -j"$(nproc)" \
    && make -j"$(nproc)" test \
    && mkdir -p '/build_root/.zlib-ng/lib/pkgconfig' \
    && mkdir -p '/build_root/.zlib-ng/share/man' \
    && checkinstall -y --nodoc --pkgversion="${zlib_ng_latest_tag_name#v}" \
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
    && curl -sS --compressed "https://github.com/openssl/openssl/archive/OpenSSL_1_1_1-stable.tar.gz" | bsdtar -xf- --strip-components 1 -C "openssl-${openssl_latest_tag_name}" \
    && pushd "/build_root/openssl-${openssl_latest_tag_name}" || exit 1 \
    && chmod +x ./config \
    && ./config --prefix="/build_root/.openssl" --release no-deprecated no-tests no-shared no-dtls1-method no-tls1_1-method no-sm2 no-sm3 no-sm4 no-rc2 no-rc4 threads CFLAGS="$CFLAGS -fPIC" CXXFLAGS="$CXXFLAGS -fPIC" \
    && make -j "$(nproc)" CFLAGS="$CFLAGS -fPIE -Wl,-pie" CXXFLAGS="$CXXFLAGS -fPIE -Wl,-pie" \
    && mkdir -p '/build_root/.openssl/lib/pkgconfig' \
    && mkdir -p '/build_root/.openssl/lib/engines-1.1' \
    && checkinstall -y --nodoc --pkgversion="$openssl_latest_tag_name" make install_sw \
    && popd || exit 1 \
    && rm -rf -- "/build_root/openssl-${openssl_latest_tag_name}" \
    && dirs -c

FROM openssl AS pcre2
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
## curl -sSL "https://ftp.pcre.org/pub/pcre/" | tr -d '\r\n\t' | grep -Po '(?<=pcre2-)[0-9]+\.[0-9]+(?=\.tar\.bz2)' | sort -Vr | head -n 1
ARG pcre2_version='10.35'
WORKDIR /build_root
RUN source '/root/.bashrc' \
    && curl -sS --compressed "https://ftp.pcre.org/pub/pcre/pcre2-${pcre2_version}.tar.bz2" | bsdtar -xf- \
    && pushd "/build_root/pcre2-${pcre2_version}" || exit 1 \
    && ./configure --prefix=/usr --enable-jit --enable-jit-sealloc --disable-shared \
    && make -j "$(nproc)" CFLAGS="$CFLAGS -fPIC" \
    && checkinstall -y --nodoc --pkgversion="$pcre2_version" \
    && popd || exit 1 \
    && rm -rf -- "/build_root/pcre2-${pcre2_version}" \
    && dirs -c
