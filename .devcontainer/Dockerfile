FROM mcr.microsoft.com/devcontainers/javascript-node:1-20-bookworm

RUN apt-get update && apt-get install -y shellcheck

# Install yq for YAML processing
RUN ARCH=$(dpkg --print-architecture) && \
    wget -qO /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${ARCH}" && \
    chmod +x /usr/local/bin/yq
