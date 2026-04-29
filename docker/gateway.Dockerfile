# Build Stage
FROM rust:1.82-slim AS builder

WORKDIR /workspace

RUN apt-get update && apt-get install -y --no-install-recommends \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

COPY conxian-gateway ./conxian-gateway

RUN cargo build --manifest-path conxian-gateway/Cargo.toml --release --locked -p gateway

# Runtime Stage
FROM debian:bookworm-slim

WORKDIR /data

RUN apt-get update && apt-get install -y --no-install-recommends \
    libssl3 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /workspace/conxian-gateway/target/release/gateway /usr/local/bin/gateway

EXPOSE 3000

ENV RUST_LOG=info
ENV API_PORT=3000

RUN useradd -m -u 10001 -s /usr/sbin/nologin gateway \
    && chown -R gateway:gateway /data

USER gateway

CMD ["gateway"]
