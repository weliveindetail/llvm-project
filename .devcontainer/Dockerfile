# Base image contents: https://github.com/microsoft/vscode-dev-containers/tree/v0.145.1/containers/cpp/.devcontainer/base.Dockerfile
ARG VARIANT="debian-10"
FROM weliveindetail/vscode-llvm-project:0-${VARIANT}

# Install tools for apt-add-repository
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive && \
    apt-get install -y --no-install-recommends \
            ca-certificates wget gnupg software-properties-common

# Add apt repository for LLVM Release 11 (October 2020)
RUN wget https://apt.llvm.org/llvm-snapshot.gpg.key && \
    apt-key add llvm-snapshot.gpg.key && \
    apt-add-repository "deb http://apt.llvm.org/buster/ llvm-toolchain-buster-11 main" && \
    apt-get update

# Install tools to build and work with LLVM
RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get -y install --no-install-recommends \
            build-essential git nano cmake ninja-build zlib1g-dev python3-dev \
            clang-11 lld-11 lldb-11

# Install arcanist for working with Phabricator reviews.
# Run `arc install-certificate` to connect your account.
RUN mkdir ~/arcanist && cd ~/arcanist &&
    git clone https://github.com/phacility/libphutil.git && \
    git clone https://github.com/phacility/arcanist.git && \
    echo 'export PATH="$PATH:/root/arcanist/arcanist/bin"' >> ~/.bash_profile

# LLDB settings and data-formatters for LLVM data structures.
RUN echo 'settings set target.x86-disassembly-flavor intel' >> ~/.lldbinit && \
    echo 'command script import "/workspaces/llvm-project/llvm/utils/lldbDataFormatters.py"' >> ~/.lldbinit

# Pull latest commits from upstream when rebuilding the container.
RUN cd /workspaces/llvm-project && git pull upstream master --rebase

# TODO for arc:
#   export PATH=$PATH:/root/arcanist/arcanist/bin
#   apt-get install php php7.3-curl

# instructions:
#   git config --global user.email a@b.c
#   git config --global user.name "Full Name"
