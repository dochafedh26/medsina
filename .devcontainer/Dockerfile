FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# Install system dependencies required by Flutter (Web, Linux, Android tooling)
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        clang \
        cmake \
        curl \
        git \
        libglu1-mesa \
        libgtk-3-dev \
        libstdc++6 \
        ninja-build \
        pkg-config \
        unzip \
        xz-utils \
        zip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install Flutter SDK (stable channel)
ENV FLUTTER_HOME="/opt/flutter"
ENV PATH="${FLUTTER_HOME}/bin:${FLUTTER_HOME}/bin/cache/dart-sdk/bin:${PATH}"

RUN git clone https://github.com/flutter/flutter.git -b stable --depth 1 "${FLUTTER_HOME}" \
    && chown -R vscode:vscode "${FLUTTER_HOME}" \
    && git config --system --add safe.directory "${FLUTTER_HOME}"

USER vscode

RUN flutter config --no-analytics --enable-web \
    && flutter precache --web \
    && flutter --version
