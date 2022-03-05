FROM registry.fedoraproject.org/fedora-minimal
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# https://api.github.com/repos/rui314/mold/releases/latest
ARG mold_latest_tag_name='v1.1'
ARG image_build_date='2022-02-17'
# http://bugs.python.org/issue19846
# > At the moment, setting "LANG=C" on a Linux system *fundamentally breaks Python 3*, and that's not OK.
ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PKG_CONFIG=/usr/bin/pkgconf \
    LDFLAGS='-fuse-ld=lld' \
    CFLAGS='-O2 -pipe -D_FORTIFY_SOURCE=2 -fexceptions -fstack-clash-protection -fstack-protector-strong -g -grecord-gcc-switches -Wl,-z,noexecstack,-z,relro,-z,now,-z,defs -Wl,--icf=all' \
    CXXFLAGS='-O2 -pipe -D_FORTIFY_SOURCE=2 -fexceptions -fstack-clash-protection -fstack-protector-strong -g -grecord-gcc-switches -Wl,-z,noexecstack,-z,relro,-z,now,-z,defs -Wl,--icf=all'
# RUN dnf install -y --setopt=install_weak_deps=False --repo=fedora --repo=updates 'dnf-command(download)' \
#     && dnf config-manager --set-disabled fedora-cisco-openh264,fedora-modular,updates-modular \
#     && dnf -y --allowerasing install 'dnf-command(versionlock)' \
RUN microdnf -y --setopt=install_weak_deps=0 --disablerepo="*" --enablerepo=fedora --enablerepo=updates --best --nodocs install \
    ca-certificates checksec coreutils curl gawk grep sed \
    bsdtar parallel \
    binutils cpp gcc gcc-c++ git-core m4 make patch pkgconf \
    clang lld \
    musl-clang musl-gcc musl-libc-static \
    cmake samurai \
    libcap \
    && microdnf -y --setopt=install_weak_deps=0 --disablerepo="*" --enablerepo=fedora --enablerepo=updates --best --nodocs upgrade \
    # && dnf -y autoremove $(dnf repoquery --installonly --latest-limit=-2 -q) \
    && microdnf clean all \
    && curl -fsSL "https://github.com/rui314/mold/releases/download/${mold_latest_tag_name}/mold-${mold_latest_tag_name#v}-x86_64-linux.tar.gz" | bsdtar -xf- --strip-components 1 -C /usr \
    && update-alternatives --install /usr/bin/ld ld /usr/bin/mold 100 \
    && update-alternatives --auto ld \
    && update-alternatives --install /usr/bin/ninja ninja /usr/bin/samu 100 \
    && update-alternatives --auto ninja
