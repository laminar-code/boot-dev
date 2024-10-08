FROM ubuntu:24.04

# Update apt package lists and upgrade current packages
RUN apt-get -yqq update
RUN apt-get -yqq upgrade

# Install nala for parallel downloads and updates
# then install base level required packages
RUN apt-get -yqq install nala
RUN nala install locales sudo make curl git slirp4netns uidmap buildah xz-utils neovim -y

# Configure locales
RUN locale-gen en_US
RUN locale-gen en_US.UTF-8
RUN dpkg-reconfigure locales
RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
RUN update-locale LANG="en_US.UTF-8" LANGUAGE="en_US"
ENV LANG en_US.UTF-8

# Configure certs
COPY certs/*.pem certs/*.crt /usr/share/ca-certificates/local
RUN cd /usr/share/ca-certificates; ls -1 local/*.pem | sudo tee -a /etc/ca-certificates.conf
RUN update-ca-certificates

# Startup at the command line
CMD /usr/bin/bash 

