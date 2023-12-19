FROM alpine:latest


# RUN apk update
RUN apk add sudo openrc bash curl btop git iptables fuse-overlayfs podman --no-cache --update
# RUN apk add --no-cache --update  fuse-overlayfs
RUN sed -i 's/#mount_program/mount_program/' /etc/containers/storage.conf


# RUN apt-get update -y
# RUN apt-get -y dist-upgrade 
# RUN apt-get -y autoremove
# RUN apt-get install locales sudo curl btop vim git slirp4netns uidmap podman -y


# RUN locale-gen en_US
# RUN locale-gen en_US.UTF-8
# RUN dpkg-reconfigure locales
# RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
# RUN update-locale LANG="en_US.UTF-8" LANGUAGE="en_US"
# ENV LANG en_US.UTF-8


RUN curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install linux \
         --extra-conf "sandbox = false" \
         --init none \
         --no-confirm
ENV PATH="${PATH}:/nix/var/nix/profiles/default/bin"


CMD /bin/bash 

