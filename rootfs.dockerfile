# syntax=docker.io/docker/dockerfile:1

ARG IMAGE_NAME=riscv64/alpine
ARG IMAGE_TAG=3.22.1

FROM ${IMAGE_NAME}:${IMAGE_TAG} AS base

RUN <<EOF
set -e
apk update
apk add --no-interactive \
    libstdc++=14.2.0-r6
EOF


FROM base AS guesttools

# Install guest tools
ARG MACHINE_GUEST_TOOLS_VERSION=0.17.1-r1
ADD --chmod=644 https://edubart.github.io/linux-packages/apk/keys/cartesi-apk-key.rsa.pub /etc/apk/keys/cartesi-apk-key.rsa.pub
RUN echo "https://edubart.github.io/linux-packages/apk/stable" >> /etc/apk/repositories
RUN apk update && apk add cartesi-machine-guest-tools=$MACHINE_GUEST_TOOLS_VERSION

FROM base AS dist

# Install guest tools
COPY --from=guesttools /usr/sbin/cartesi-init /usr/sbin/cartesi-init
COPY --from=guesttools /usr/sbin/xhalt /usr/sbin/xhalt

# Install Riv
ARG RIV_VERSION=0.3-rc16
ADD --chmod=644 https://github.com/rives-io/riv/releases/download/v${RIV_VERSION}/rivos.ext2 /rivos.ext2
ADD --chmod=644 https://raw.githubusercontent.com/rives-io/riv/v${RIV_VERSION}/rivos/skel/etc/sysctl.conf /etc/sysctl.conf
ADD --chmod=755 https://raw.githubusercontent.com/rives-io/riv/v${RIV_VERSION}/rivos/skel/etc/cartesi-init.d/riv-init /etc/cartesi-init.d/riv-init
RUN mkdir -p /rivos

# Install Riv scripts
COPY --chmod=755 <<EOF /etc/cartesi-init.d/envs-init
export PATH="/usr/local/sbin:/usr/local/bin:$PATH"
EOF

COPY --chmod=755 <<EOF /etc/cartesi-init.d/riv-mount-init
mount -o ro,noatime,nosuid -t ext2 /rivos.ext2 /rivos
mount --bind /cartridges /rivos/cartridges
EOF

# Remove unneeded packages to shrink image and cleanup
RUN <<EOF
set -e
apk del --purge apk-tools alpine-release alpine-keys ca-certificates-bundle libc-utils
rm -rf /etc/apk /lib/apk
rm -rf /var/log/* /var/cache/* /tmp/*
EOF

COPY cartridges /cartridges

RUN adduser -D app app 2>/dev/null

WORKDIR /mnt/app
