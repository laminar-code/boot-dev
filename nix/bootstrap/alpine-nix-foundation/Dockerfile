FROM alpine:3.22.2

# hadolint ignore=DL3018
RUN apk add sudo openrc bash curl btop git iptables fuse-overlayfs podman --no-cache --update \
  && sed -i 's/#mount_program/mount_program/' /etc/containers/storage.conf

SHELL ["/bin/ash", "-c", "-o pipefail"]

RUN curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | /bin/ash -s -- install linux \
  --extra-conf "sandbox = false" \
  --init none \
  --no-confirm
ENV PATH="${PATH}:/nix/var/nix/profiles/default/bin"

CMD ["/bin/bash"]

