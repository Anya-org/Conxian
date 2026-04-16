FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
        python3.10 \
        python3.10-venv \
        python3-pip \
        curl \
        build-essential \
        pkg-config \
        libssl-dev \
        protobuf-compiler \
    && ln -sf /usr/bin/python3.10 /usr/local/bin/python3 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Rust stable toolchain
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --profile minimal
ENV PATH="/root/.cargo/bin:${PATH}"
