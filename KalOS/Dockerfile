ARG DEBIAN_FRONTEND=noninteractive
FROM debian:bookworm-slim

# Базовые инструменты для сборки ядра, BusyBox и ISO (GRUB)
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       bash ca-certificates build-essential bc bison flex \
       libelf-dev libssl-dev libncurses-dev xz-utils \
       wget curl cpio xorriso grub-pc-bin grub-efi-amd64-bin mtools \
       git \
    && rm -rf /var/lib/apt/lists/*

ARG KERNEL_VERSION=6.6.35
ARG BUSYBOX_VERSION=1.36.1
ENV KERNEL_VERSION=${KERNEL_VERSION} \
    BUSYBOX_VERSION=${BUSYBOX_VERSION}

WORKDIR /work

# Образ только как билд-окружение; исходники монтируются в /src при запуске контейнера
CMD ["bash", "-lc", "echo 'Use: docker run -v $PWD:/src -w /src <image> bash -lc \"/src/build/build.sh\"' && sleep 2"]


