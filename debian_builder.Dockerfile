FROM mirror.gcr.io/bitnami/minideb:bookworm AS base
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ARG DEBIAN_FRONTEND=noninteractive
# https://api.github.com/repos/slimm609/checksec.sh/releases/latest
ARG checksec_latest_tag_name='2.5.0'
# https://api.github.com/repos/Kitware/CMake/tags?per_page=100
ARG cmake_latest_tag_name='v3.22.3'
# https://api.github.com/repos/ninja-build/ninja/releases/latest
ARG ninja_latest_tag_name='v1.10.2'
# https://api.github.com/repos/mesonbuild/meson/releases/latest
ARG meson_latest_tag_name='0.61.2'
# https://api.github.com/repos/sabotage-linux/netbsd-curses/releases/latest
# ARG netbsd_curses_tag_name='0.3.1'
# https://api.github.com/repos/sabotage-linux/gettext-tiny/releases/latest
# ARG gettext_tiny_tag_name='0.3.2'
ARG image_build_date='2022-03-09'
# http://bugs.python.org/issue19846
# > At the moment, setting "LANG=C" on a Linux system *fundamentally breaks Python 3*, and that's not OK.
ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    CFLAGS='-O2 -pipe -D_FORTIFY_SOURCE=2 -fexceptions -fstack-clash-protection -fstack-protector-strong -g -grecord-gcc-switches -Wl,-z,noexecstack,-z,relro,-z,now,-z,defs -Wl,--icf=all' \
    CXXFLAGS='-O2 -pipe -D_FORTIFY_SOURCE=2 -fexceptions -fstack-clash-protection -fstack-protector-strong -g -grecord-gcc-switches -Wl,-z,noexecstack,-z,relro,-z,now,-z,defs -Wl,--icf=all' \
    PATH=/root/.local/bin:$PATH \
    PKG_CONFIG=/usr/bin/pkgconf \
    PKG_CONFIG_PATH=/usr/lib64/pkgconfig:$PKG_CONFIG_PATH
RUN echo -e 'deb http://deb.debian.org/debian bookworm main\ndeb http://security.debian.org/debian-security bookworm-security main\ndeb http://deb.debian.org/debian bookworm-updates main\ndeb http://deb.debian.org/debian bookworm-backports main' > /etc/apt/sources.list \
    && apt-get update -qq && apt-get full-upgrade -y \
    && apt-get -y --no-install-recommends install \
    ca-certificates curl gpg gpg-agent \
    && curl -fsSL 'https://apt.llvm.org/llvm-snapshot.gpg.key' | apt-key add - \
    && echo 'deb http://apt.llvm.org/bookworm/ llvm-toolchain-bookworm main' > /etc/apt/sources.list.d/llvm.list \
    && install_packages \
    binutils build-essential checkinstall cmake coreutils dos2unix file git libarchive-tools libedit-dev libltdl-dev libncurses-dev libsystemd-dev libtool-bin netbase ninja-build pipx pkgconf python3-pip python3-venv util-linux \
    clang lld \
    && apt-get -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false purge \
    && update-alternatives --install /usr/bin/pkg-config pkg-config /usr/bin/pkgconf 100 \
    && update-alternatives --auto pkg-config \
    && echo "alias mkdir='mkdir -p'" >> ~/.bashrc \
    && echo "alias xargs='xargs -r -s 2000'" >> ~/.bashrc \
    && echo "alias pip3='python3 -m pip'" >> ~/.bashrc \
    && echo "alias checkinstall='checkinstall --nodoc'" >> ~/.bashrc \
    && echo "alias git_clone='git clone -j "'"$(nproc)"'" --no-tags --shallow-submodules --recurse-submodules --depth 1 --single-branch'" >> ~/.bashrc \
    && curl --retry 5 --retry-delay 10 --retry-max-time 60 --connect-timeout 60 --fail -sSL -m 600 -o '/usr/bin/checksec' "https://raw.githubusercontent.com/slimm609/checksec.sh/${checksec_latest_tag_name}/checksec" \
    && chmod +x '/usr/bin/checksec' \
    && ( tmp_dir=$(mktemp -d) && pushd "$tmp_dir" || exit 1 && curl --retry 5 --retry-delay 10 --retry-max-time 60 --connect-timeout 60 -fsSL --compressed -o "cmake-${cmake_latest_tag_name#v}-Linux-x86_64.sh" "https://github.com/Kitware/CMake/releases/download/${cmake_latest_tag_name}/cmake-${cmake_latest_tag_name#v}-Linux-x86_64.sh" && bash "cmake-${cmake_latest_tag_name#v}-Linux-x86_64.sh" --skip-license --exclude-subdir --prefix=/usr && rm -rf "cmake-${cmake_latest_tag_name#v}-Linux-x86_64.sh" '/usr/bin/cmake-gui' '/usr/bin/ccmake' '/usr/bin/ctest' '/usr/share/cmake-3.18' && popd || exit 1 && dirs -c ) \
    && ( tmp_dir=$(mktemp -d) && pushd "$tmp_dir" || exit 1 && curl --retry 5 --retry-delay 10 --retry-max-time 60 --connect-timeout 60 -fsSL "https://github.com/ninja-build/ninja/releases/download/${ninja_latest_tag_name}/ninja-linux.zip" | bsdtar -xf- && $(type -P install) -pvD './ninja' '/usr/bin/' && popd || exit 1 && /bin/rm -rf "$tmp_dir" && dirs -c ) \
    && pipx install meson \
    && pipx ensurepath \
    && rm -rf "$HOME/.cache/pip" \
    && mkdir '/build_root' \
    && mkdir '/usr/local/doc' \
    && mkdir '/usr/local/share/doc'
    ### https://github.com/sabotage-linux/netbsd-curses
    # && curl --retry 5 --retry-delay 10 --retry-max-time 60 --connect-timeout 60 -fsSL "http://ftp.barfooze.de/pub/sabotage/tarballs/netbsd-curses-${netbsd_curses_tag_name}.tar.xz" | bsdtar -xf- \
    # && ( cd "/netbsd-curses-${netbsd_curses_tag_name}" || exit 1; checkinstall -y --nodoc --pkgversion="$netbsd_curses_tag_name" --dpkgflags="--force-overwrite" make CFLAGS="$CFLAGS -fPIC" PREFIX=/usr -j "$(nproc)" all install ) \
    # && rm -rf "/netbsd-curses-${netbsd_curses_tag_name}" \
    ### https://github.com/sabotage-linux/gettext-tiny
    # && curl --retry 5 --retry-delay 10 --retry-max-time 60 --connect-timeout 60 -fsSL "http://ftp.barfooze.de/pub/sabotage/tarballs/gettext-tiny-${gettext_tiny_tag_name}.tar.xz" | bsdtar -xf- \
    # && ( cd "/gettext-tiny-${gettext_tiny_tag_name}" || exit 1; checkinstall -y --nodoc --pkgversion="$gettext_tiny_tag_name" --dpkgflags="--force-overwrite" make CFLAGS="$CFLAGS -fPIC" PREFIX=/usr -j "$(nproc)" all install ) \
    # && rm -rf "/gettext-tiny-${gettext_tiny_tag_name}"

FROM base AS mold
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# https://api.github.com/repos/rui314/mold/releases/latest
ARG mold_latest_tag_name='v1.1.1'
RUN curl --retry 5 --retry-delay 10 --retry-max-time 60 -fsSL "https://github.com/rui314/mold/releases/download/${mold_latest_tag_name}/mold-${mold_latest_tag_name#v}-x86_64-linux.tar.gz" | bsdtar -xf- --strip-components 1 -C /usr \
    && update-alternatives --install /usr/bin/ld ld /usr/bin/ld.mold 100 \
    && update-alternatives --auto ld

FROM mold AS parallel
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
## curl -sSL "https://ftpmirror.gnu.org/parallel/" | tr -d '\r\n\t' | grep -Po '(?<=parallel-)[0-9]+(?=\.tar\.bz2)' | sort -Vr | head -n 1
ARG parallel_version='20220222'
ARG dockerfile_workdir=/build_root/parallel
WORKDIR $dockerfile_workdir
RUN curl --retry 5 --retry-delay 10 --retry-max-time 60 -fsSL "https://ftpmirror.gnu.org/parallel/parallel-${parallel_version}.tar.bz2" | bsdtar -xf- --strip-components 1 \
    && CFLAGS="$CFLAGS -fPIC" \
    && CXXFLAGS="$CXXFLAGS -fPIC" \
    && LDFLAGS="$LDFLAGS -pie" \
    && export CFLAGS CXXFLAGS LDFLAGS \
    && ./configure --prefix=/usr \
    && make -j"$(nproc)" \
    && make install \
    && mkdir -p "$HOME/.parallel" \
    && touch "$HOME/.parallel/will-cite" \
    && rm -rf -- "$dockerfile_workdir"

FROM parallel AS zlib-ng
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
    && checkinstall -y --nodoc --pkgversion="${zlib_ng_latest_tag_name#v}" \
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
    && ./config --prefix=/usr --release no-deprecated no-tests no-shared no-dtls1-method no-tls1_1-method no-md4 no-sm2 no-sm3 no-sm4 no-rc2 no-rc4 threads \
    && make -j "$(nproc)" \
    && checkinstall -y --nodoc --pkgname=openssl --pkgversion="$openssl_latest_tag_name" --dpkgflags='--force-overwrite' make install_sw \
    && rm -rf -- "$dockerfile_workdir"

FROM openssl AS pcre2
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
## https://api.github.com/repos/PhilipHazel/pcre2/releases/latest
ARG pcre2_version='pcre2-10.39'
ARG dockerfile_workdir=/build_root/pcre2
WORKDIR $dockerfile_workdir
RUN curl -sSL "https://github.com/PhilipHazel/pcre2/releases/latest/download/${pcre2_version}.tar.bz2" | bsdtar -xf- --strip-components 1 \
    && CFLAGS="$CFLAGS -mshstk -fPIC" \
    && CXXFLAGS="$CXXFLAGS -mshstk -fPIC" \
    && LDFLAGS="$LDFLAGS -pie" \
    && export CFLAGS CXXFLAGS LDFLAGS \
    && ./configure --prefix=/usr --enable-jit --enable-jit-sealloc \
    && make -j "$(nproc)" \
    && checkinstall -y --nodoc --pkgversion="${pcre2_version##pcre2-}" \
    # && mv "./${pcre2_version/-/_}-1_amd64.deb" "/build_root/${pcre2_version/-/_}-1_amd64.deb" \
    && rm -rf -- "$dockerfile_workdir"
