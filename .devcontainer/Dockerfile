# Use a specific tag for the bookworm image to ensure reproducibility
ARG IMAGE=python
ARG TAG=3.11-bookworm
FROM --platform=amd64 mcr.microsoft.com/devcontainers/${IMAGE}:${TAG} as base

# Setting frontend to noninteractive to avoid user prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Combine RUN instructions to reduce layers, install necessary packages, and clean up in one layer to reduce image size
RUN apt-get update && \
    apt-get install -y --no-install-recommends xdg-utils && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Install Azure Developer CLI (azd) from the stable release channel
RUN curl -fsSL https://aka.ms/install-azd.sh | bash
