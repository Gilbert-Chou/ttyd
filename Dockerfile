# --- Stage 1: Builder ---
FROM node:24.14.0-bookworm AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    bash git build-essential cmake \
    libjson-c-dev libwebsockets-dev libuv1-dev zlib1g-dev

WORKDIR /app
RUN git clone https://github.com/Gilbert-Chou/ttyd.git .

# Build frontend
WORKDIR /app/html
RUN npm install && corepack enable && yarn install && yarn run build

# Build backend
WORKDIR /app/build
RUN cmake .. && make -j$(nproc)

# Export compile file to /app/output
RUN make DESTDIR=/app/output install

# --- Stage 2: Runner ---
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# 1. Install Runtime packages
RUN apt update && apt install -y --no-install-recommends \
    openssh-client \
    bash \
    libjson-c5 \
    libwebsockets17 \
    libwebsockets-evlib-uv \
    libuv1 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/output/usr/local /usr/local

RUN ttyd --version

EXPOSE 7681
ENTRYPOINT ["ttyd", "--writable", "--client-option", "disableReconnect=true", "--url-arg", "ssh", "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null"]