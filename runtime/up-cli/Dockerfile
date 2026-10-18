# UltraPads 无头 CLI 镜像（ghcr.io/plutokeating/ultrapads-cli）
# 构建：仓库根目录执行 docker build -f runtime/up-cli/Dockerfile -t ultrapads-cli .
FROM rust:1-bookworm AS build
# 音频基座：ALSA + PipeWire 原生后端（cpal pipewire，bindgen 需要 clang）+ rtkit 实时提权（dbus）
RUN apt-get update && apt-get install -y --no-install-recommends \
      libasound2-dev libpipewire-0.3-dev libspa-0.2-dev libdbus-1-dev clang pkg-config \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /src
COPY . .
RUN cargo build --release --locked -p up-cli

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends libasound2 libpipewire-0.3-0 libdbus-1-3 \
    && rm -rf /var/lib/apt/lists/*
COPY --from=build /src/target/release/up-cli /usr/local/bin/up-cli
LABEL org.opencontainers.image.source="https://github.com/PlutoKeating/Project.UltraPads" \
      org.opencontainers.image.description="UltraPads headless CLI: offline render, play, latency probe, WAV inspect" \
      org.opencontainers.image.licenses="Apache-2.0"
ENTRYPOINT ["up-cli"]
