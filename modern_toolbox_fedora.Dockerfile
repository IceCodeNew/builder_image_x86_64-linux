FROM registry.fedoraproject.org/fedora-minimal AS base
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# https://api.github.com/repos/rui314/mold/releases/latest
ARG mold_latest_tag_name='v1.1'
ARG image_build_date='2022-02-17'
# http://bugs.python.org/issue19846
# > At the moment, setting "LANG=C" on a Linux system *fundamentally breaks Python 3*, and that's not OK.
ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PKG_CONFIG=/usr/bin/pkgconf \
    CFLAGS='-O2 -pipe -D_FORTIFY_SOURCE=2 -fexceptions -fstack-clash-protection -fstack-protector-strong -g -grecord-gcc-switches -Wl,-z,noexecstack,-z,relro,-z,now,-z,defs -Wl,--icf=all' \
    CXXFLAGS='-O2 -pipe -D_FORTIFY_SOURCE=2 -fexceptions -fstack-clash-protection -fstack-protector-strong -g -grecord-gcc-switches -Wl,-z,noexecstack,-z,relro,-z,now,-z,defs -Wl,--icf=all'
    # LDFLAGS='-fuse-ld=mold' \

# RUN dnf install -y --setopt=install_weak_deps=False --repo=fedora --repo=updates 'dnf-command(download)' \
#     && dnf config-manager --set-disabled fedora-cisco-openh264,fedora-modular,updates-modular \
#     && dnf -y --allowerasing install 'dnf-command(versionlock)' \
RUN microdnf -y --setopt=install_weak_deps=0 --disablerepo="*" --enablerepo=fedora --enablerepo=updates --best --nodocs install \
    ca-certificates checksec coreutils curl gawk grep perl sed \
    bsdtar parallel \
    binutils cpp gcc gcc-c++ git-core m4 make patch pkgconf \
    clang lld \
    musl-clang musl-gcc musl-libc-static \
    cmake samurai \
    libcap \
    && microdnf -y --setopt=install_weak_deps=0 --disablerepo="*" --enablerepo=fedora --enablerepo=updates --best --nodocs upgrade \
    # && dnf -y autoremove $(dnf repoquery --installonly --latest-limit=-2 -q) \
    && microdnf clean all \
    && update-alternatives --install /usr/bin/ninja ninja /usr/bin/samu 100 \
    && update-alternatives --auto ninja

FROM base AS mold
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# https://api.github.com/repos/rui314/mold/releases/latest
ARG mold_latest_tag_name='v1.1'
RUN curl --retry 5 --retry-delay 10 --retry-max-time 60 -fsSL "https://github.com/rui314/mold/releases/download/${mold_latest_tag_name}/mold-${mold_latest_tag_name#v}-x86_64-linux.tar.gz" | bsdtar -xf- --strip-components 1 -C /usr \
    && update-alternatives --install /usr/bin/ld ld /usr/bin/mold 100 \
    && update-alternatives --auto ld

FROM mold AS zlib-ng
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# https://api.github.com/repos/zlib-ng/zlib-ng/releases/latest
ARG zlib_ng_latest_tag_name='2.0.6'
ARG dockerfile_workdir=/build_root/zlib-ng
WORKDIR $dockerfile_workdir
RUN curl --retry 5 --retry-delay 10 --retry-max-time 60 -fsSL "https://github.com/zlib-ng/zlib-ng/archive/refs/tags/${zlib_ng_latest_tag_name}.tar.gz" | bsdtar -xf- --strip-components 1 \
    && CFLAGS="$CFLAGS -fPIC" \
    && CXXFLAGS="$CXXFLAGS -fPIC" \
    && LDFLAGS="-pie -s" \
    && export CFLAGS CXXFLAGS LDFLAGS \
    && env \
    && prefix=/usr ./configure --static --zlib-compat \
    && make -j"$(nproc)" \
    && make -j"$(nproc)" test \
    && make install \
    && rm -rf -- "$dockerfile_workdir"

FROM zlib-ng AS openssl
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# https://api.github.com/repos/openssl/openssl/commits?per_page=1&sha=OpenSSL_1_1_1-stable
ARG openssl_latest_commit_hash='4bb34766d41489cfe95002e861f4a655727ebaf9'
## curl -fsSL 'https://raw.githubusercontent.com/openssl/openssl/OpenSSL_1_1_1-stable/README' | grep -Eo '1.1.1.*'
ARG openssl_latest_tag_name=1.1.1n-dev
ARG dockerfile_workdir=/build_root/openssl-1.1
WORKDIR $dockerfile_workdir
RUN curl --retry 5 --retry-delay 10 --retry-max-time 60 -fsSL "https://github.com/openssl/openssl/archive/OpenSSL_1_1_1-stable.tar.gz" | bsdtar -xf- --strip-components 1 \
    && CFLAGS="$CFLAGS -fPIC" \
    && CXXFLAGS="$CXXFLAGS -fPIC" \
    && LDFLAGS="-pie -s" \
    && export CFLAGS CXXFLAGS LDFLAGS \
    && env \
    && ./config --prefix=/usr --openssldir=/etc/pki/tls --release threads no-shared no-deprecated no-tests no-dtls1-method no-tls1_1-method no-md4 no-sm2 no-sm3 no-sm4 no-rc2 no-rc4 \
    && make -j "$(nproc)" \
    && make install_sw \
    && rm -rf -- "$dockerfile_workdir" \
    && readelf -p .comment /usr/bin/openssl
