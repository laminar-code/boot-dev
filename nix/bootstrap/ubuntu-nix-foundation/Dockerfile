FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive

# Update apt package lists and upgrade current packages
RUN apt-get -yqq update
RUN apt-get -yqq upgrade

# Install nala for parallel downloads and updates
# then install base level required packages
RUN apt-get -yqq install nala
RUN nala install locales sudo make curl git slirp4netns uidmap buildah xz-utils nano gcc -y

# Configure locales
RUN locale-gen en_US
RUN locale-gen en_US.UTF-8
RUN dpkg-reconfigure locales
RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
RUN update-locale LANG="en_US.UTF-8" LANGUAGE="en_US"
ENV LANG en_US.UTF-8
ENV LANGUAGE="en_US"

# Configure certs
COPY ubuntu-nix-foundation/certs/.placeholder ubuntu-nix-foundation/certs/*.crt /usr/local/share/ca-certificates/
RUN update-ca-certificates

# Startup at the command line
CMD /usr/bin/bash 

