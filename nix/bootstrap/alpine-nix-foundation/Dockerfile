FROM alpine:latest

RUN apk add sudo openrc bash curl btop git iptables fuse-overlayfs podman --no-cache --update
RUN sed -i 's/#mount_program/mount_program/' /etc/containers/storage.conf

RUN curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install linux \
         --extra-conf "sandbox = false" \
         --init none \
         --no-confirm
ENV PATH="${PATH}:/nix/var/nix/profiles/default/bin"

CMD /bin/bash 

