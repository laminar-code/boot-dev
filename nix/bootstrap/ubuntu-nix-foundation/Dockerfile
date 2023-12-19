FROM ubuntu:latest
RUN apt -y update
RUN apt -y upgrade
RUN apt -y install nala
RUN nala install locales sudo curl git slirp4netns uidmap buildah -y


RUN locale-gen en_US
RUN locale-gen en_US.UTF-8
RUN dpkg-reconfigure locales
RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
RUN update-locale LANG="en_US.UTF-8" LANGUAGE="en_US"
ENV LANG en_US.UTF-8


RUN curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install linux \
         --extra-conf "sandbox = false" \
         --init none \
         --no-confirm
ENV PATH="${PATH}:/nix/var/nix/profiles/default/bin"


CMD /usr/bin/bash

