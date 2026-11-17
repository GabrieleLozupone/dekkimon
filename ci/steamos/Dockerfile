# Build environment that matches SteamOS 3.9 (the Steam Deck's libraries and Qt version).
# Same setup as the local WSL build container: Arch Linux switched to Valve's SteamOS package
# mirror, then every package synced (and downgraded where needed) to SteamOS's versions.
#
#   docker build -t dekkimon-build ci/steamos
FROM archlinux:base-devel

ARG STEAMOS_MIRROR=https://steamdeck-packages.steamos.cloud/archlinux-mirror
# Keyrings that sign the SteamOS repos, pinned by hash.
ARG HOLO_KEYRING=holo-3.9/os/x86_64/holo-keyring-20241029-1.2-any.pkg.tar.zst
ARG HOLO_KEYRING_SHA256=00ded07d81704742dd3321ad9aeefc9b325fe9c27c28c8d74b5bac0c35ca7b4e
ARG ARCH_KEYRING=core-3.9/os/x86_64/archlinux-keyring-20260707.1-1-any.pkg.tar.zst
ARG ARCH_KEYRING_SHA256=b47fc9c8066377e73d72bdb6a166bbbd829d5dcc745e424ef32436bd673cbc0d

COPY pacman.conf /tmp/steamos-pacman.conf
RUN set -eux; \
    cd /tmp; \
    curl -fsSL -o holo.pkg "$STEAMOS_MIRROR/$HOLO_KEYRING"; \
    curl -fsSL -o arch.pkg "$STEAMOS_MIRROR/$ARCH_KEYRING"; \
    echo "$HOLO_KEYRING_SHA256  holo.pkg" | sha256sum -c -; \
    echo "$ARCH_KEYRING_SHA256  arch.pkg" | sha256sum -c -; \
    mkdir keyrings; \
    tar --zstd -xf holo.pkg -C keyrings; \
    tar --zstd -xf arch.pkg -C keyrings; \
    cp keyrings/usr/share/pacman/keyrings/* /usr/share/pacman/keyrings/; \
    cp /tmp/steamos-pacman.conf /etc/pacman.conf; \
    rm -rf keyrings holo.pkg arch.pkg; \
    pacman-key --init; \
    pacman-key --populate archlinux holo; \
    pacman -Syyuu --noconfirm; \
    pacman -S --needed --noconfirm base-devel cmake ninja qt6-base qt6-declarative qt6-svg \
        qt6-webengine qt6-shadertools ffmpeg libplacebo sdl2-compat opus speexdsp hidapi fftw \
        json-c miniupnpc libevent curl protobuf python-protobuf git pkgconf vulkan-headers \
        vulkan-icd-loader; \
    pacman -Scc --noconfirm; \
    rm -rf /var/cache/pacman/pkg/*
