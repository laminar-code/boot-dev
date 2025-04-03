FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive

ENV LANG en_US.UTF-8
ENV LANGUAGE="en_US"

# Configure certs
COPY ubuntu-nix-foundation/certs/.placeholder ubuntu-nix-foundation/certs/*.crt /usr/local/share/ca-certificates/

# Update certs then update apt package lists and upgrade current packages
# Install nala for parallel downloads and updates
# then install base level required packages
# Configure locales
RUN apt-get -yqq update; apt-get -yqq upgrade; \
    apt-get -yqq install nala; nala install locales sudo make curl git slirp4netns uidmap buildah xz-utils nano gcc -y; \
    update-ca-certificates; \
    locale-gen en_US; locale-gen en_US.UTF-8; dpkg-reconfigure locales; \
    localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8; \
    update-locale LANG="en_US.UTF-8" LANGUAGE="en_US"

# Startup at the command line
CMD /usr/bin/bash 

