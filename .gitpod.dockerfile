# JitFromScratch docker image for development in GitPod
FROM ubuntu:19.04
LABEL maintainer="weliveindetail <stefan.graenitz@gmail.com>"

# Install tools and libs for building and debugging
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates build-essential git cmake cmake-data \
        ninja-build clang lldb lld zlib1g-dev python3-dev && \
    rm -rf /var/lib/apt/lists/*

# CMD is ignored and instead the init command from the top-level .gitpod.yml
# runs on first startup of the containter in your GitPod workspace.
