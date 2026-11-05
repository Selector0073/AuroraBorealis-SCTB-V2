FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    TERM=xterm-256color \
    container=docker

RUN apt-get update && apt-get install -y --no-install-recommends \
        systemd \
        systemd-sysv \
        dbus \
        libpam-systemd \
        ca-certificates \
        curl \
        nano \
        less \
        procps \
        iproute2 \
        iputils-ping \
        net-tools \
        file \
    && rm -rf /var/lib/apt/lists/*

RUN systemctl mask \
        systemd-udevd.service \
        systemd-udev-trigger.service \
        systemd-udevd-control.socket \
        systemd-udevd-kernel.socket \
        systemd-modules-load.service \
        systemd-resolved.service \
        systemd-networkd.service \
        systemd-networkd-wait-online.service \
        systemd-timesyncd.service \
        systemd-remount-fs.service \
        getty.target \
        console-getty.service \
        getty@.service \
        sys-kernel-config.mount \
        sys-kernel-debug.mount \
        sys-kernel-tracing.mount \
        dev-hugepages.mount

COPY release-server/ /root/release/

WORKDIR /root/release

STOPSIGNAL SIGRTMIN+3

CMD ["/sbin/init"]