FROM ubuntu:24.04
# FROM registry.digitalocean.com/laminar-registry/ubuntu-nix-foundation:1

# Set LANG in user environment
ENV LANG=en_US.utf8
ENV LANGUAGE="en_US"

# Declare args
ARG username
ARG git_utils_repo
ARG DEBIAN_FRONTEND=noninteractive

ARG OCI_TITLE_LABEL=org.opencontainers.image.title
ARG OCI_TITLE_VALUE=ERROR
ARG OCI_DESCRIPTION_LABEL=org.opencontainers.image.description
ARG OCI_DESCRIPTION_VALUE=ERROR
ARG OCI_CREATED_LABEL=org.opencontainers.image.created
ARG OCI_CREATED_VALUE=ERROR
ARG OCI_AUTHORS_LABEL=org.opencontainers.image.authors
ARG OCI_AUTHORS_VALUE=ERROR
ARG OCI_VENDOR_LABEL=org.opencontainers.image.vendor
ARG OCI_VENDOR_VALUE=ERROR
ARG OCI_LICENSE_LABEL=org.opencontainers.image.licenses
ARG OCI_LICENSE_VALUE=ERROR
ARG OCI_SOURCE_LABEL=org.opencontainers.image.source
ARG OCI_SOURCE_VALUE=ERROR
ARG OCI_URL_LABEL=org.opencontainers.image.url
ARG OCI_URL_VALUE=ERROR
ARG OCI_DOCS_LABEL=org.opencontainers.image.documentation
ARG OCI_DOCS_VALUE=ERROR
ARG OCI_VERSION_LABEL=org.opencontainers.image.version
ARG OCI_VERSION_VALUE=ERROR
ARG OCI_REVISION_LABEL=org.opencontainers.image.revision
ARG OCI_REVISION_VALUE=ERROR
ARG OCI_REFNAME_LABEL=org.opencontainers.image.ref.name
ARG OCI_REFNAME_VALUE=ERROR

ARG HOME_DIR=/home/${username}

# hadolint ignore=DL3048
LABEL ${OCI_TITLE_LABEL}=${OCI_TITLE_VALUE}
# hadolint ignore=DL3048
LABEL ${OCI_DESCRIPTION_LABEL}=${OCI_DESCRIPTION_VALUE}
# hadolint ignore=DL3048
LABEL ${OCI_CREATED_LABEL}=${OCI_CREATED_VALUE}
# hadolint ignore=DL3048
LABEL ${OCI_AUTHORS_LABEL}=${OCI_AUTHORS_VALUE}
# hadolint ignore=DL3048
LABEL ${OCI_VENDOR_LABEL}=${OCI_VENDOR_VALUE}
# hadolint ignore=DL3048
LABEL ${OCI_LICENSE_LABEL}=${OCI_LICENSE_VALUE}
# hadolint ignore=DL3048
LABEL ${OCI_SOURCE_LABEL}=${OCI_SOURCE_VALUE}
# hadolint ignore=DL3048
LABEL ${OCI_URL_LABEL}=${OCI_URL_VALUE}
# hadolint ignore=DL3048
LABEL ${OCI_DOCS_LABEL}=${OCI_DOCS_VALUE}
# hadolint ignore=DL3048
LABEL ${OCI_VERSION_LABEL}=${OCI_VERSION_VALUE}
# hadolint ignore=DL3048
LABEL ${OCI_REVISION_LABEL}=${OCI_REVISION_VALUE}
# hadolint ignore=DL3048
LABEL ${OCI_REFNAME_LABEL}=${OCI_REFNAME_VALUE}

# Configure certs
COPY .build/certs/.placeholder .build/certs/*.crt /usr/local/share/ca-certificates/

# Update certs then update apt package lists and upgrade current packages
# Install nala for parallel downloads and updates
# then install base level required packages
# Configure locales
RUN apt-get -yqq update \
  && apt-get -yqq upgrade \
  && apt-get -yqq install nala=0.15.1 --no-install-recommends \
  && nala install -y locales sudo make curl git slirp4netns uidmap buildah xz-utils nano gcc \
  && nala clean --lists \
  && rm -rf /var/lib/apt/lists/* \
  && update-ca-certificates \
  && locale-gen en_US; locale-gen en_US.UTF-8; dpkg-reconfigure locales \
  && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 \
  && update-locale LANG="en_US.UTF-8" LANGUAGE="en_US" \
  # Set up local user and add to sudoers w/o password requirement
  && adduser --shell /usr/bin/bash ${username} \
  && groupadd -g 9999 devs \
  && usermod -a -G devs ${username} \
  && adduser ${username} sudo \
  && echo "${username} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/${username} \
  # Install nix
  && mkdir -m 0755 /nix \
  && curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix > nix-installer.sh \
  && chmod +x nix-installer.sh \
  && ./nix-installer.sh install linux --init none --no-confirm --extra-conf "filter-syscalls = false" \
  && chown ${username}:${username} /nix -R

USER ${username}
ENV  USER=${username}
ENV  PATH=${PATH}:/nix/var/nix/profiles/default/bin:/home/${username}/.nix-profile/bin
# Add .ssh config to user
COPY --chown=${username}:${username} .build/.ssh/.placeholder .build/.ssh/ /home/${username}/.ssh/
# Copy in .env
COPY --chown=${username}:${username} .env /home/${username}/.env.boot-dev

WORKDIR /home/${username}
RUN  find ./.ssh -type f -exec chmod 600 {} + \
  && find ./.ssh -type d -exec chmod 700 {} + \
  # Clone repos for dev config
  && mkdir git \
  && git clone https://github.com/laminar-code/boot-dev.git git/boot-dev \
  # Link config dot files with dev config repos
  && mkdir -p ./.config \
  && ln -s ${HOME_DIR}/git/boot-dev/nix/config        .config/nix \
  && ln -s ${HOME_DIR}/git/boot-dev/tmux              .config/tmux \
  && ln -s ${HOME_DIR}/git/boot-dev/nvim              .config/nvim \
  && ln -s ${HOME_DIR}/git/boot-dev/nix/home-manager  .config/home-manager \
  && ln -s ${HOME_DIR}/git/boot-dev/lazygit           .config/lazygit \
  # Link ~/bin files with dev config repos
  && mkdir bin \
  && ln -s ${HOME_DIR}/git/boot-dev/git/clone             bin/clone \
  && ln -s ${HOME_DIR}/git/boot-dev/git/clone-files-only  bin/clone-files-only \
  && ln -s ${HOME_DIR}/git/boot-dev/git/switch-origin     bin/switch-origin \
  && ln -s ${HOME_DIR}/git/boot-dev/nix/bin/dev           bin/dev \
  # Create link for /mnt/host
  && ln -s /mnt/host host \
  # Move .profile and .bashrc out of the way
  && mv .profile .profile.orig \
  && mv .bashrc .bashrc.orig

# Resumed use of determinate systems installer
# USER ${username}
# RUN  curl -L https://nixos.org/nix/install | sh -s -- --no-daemon --extra-conf "filter-syscalls = false"

RUN  nix-channel --add https://github.com/nixos/nixpkgs/archive/nixpkgs-unstable.tar.gz nixpkgs \
  && nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager \
  && nix-channel --update

# Configure and install home-manager and run initial home-manager switch
# This is retained for future but causes some warnings due to a release mismatch
# USER ${username}
# RUN  nix-shell '<home-manager>' -A install
# 
# # Link to devenv flake
# USER ${username}
# RUN ln -s /home/${username}/git/boot-dev/nix/devenv /home/${username}/devenv
# 
# # Initialize Neovim plugins
# USER ${username}
# RUN  nvim --headless "+Lazy! sync" +qa

# Set workdir to start shell in home directory
USER    ${username}
WORKDIR /home/${username}

# Startup at the command line
CMD ["/usr/bin/bash"]

