FROM ubuntu-nix-foundation

# Declare args
ARG username
ARG git_bearer_token
ARG git_utils_repo
ARG DEBIAN_FRONTEND=noninteractive

# Set up local user and add to sudoers w/o password requirement
RUN  adduser --shell /usr/bin/bash ${username}
ARG  username=${username}
RUN  adduser ${username} sudo
RUN  echo "${username} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/${username}

# Add .ssh config to user
COPY ubuntu-nix-dev/.ssh/.placeholder ubuntu-nix-dev/.ssh/* /home/${username}/.ssh/
RUN  chown -R ${username}:${username} /home/${username}/.ssh
RUN  chmod -R 600 /home/${username}/.ssh
RUN  chmod 700 /home/${username}/.ssh

# Set LANG and USER in user environment
USER ${username}
ENV LANG=en_US.utf8
ENV USER=${username}

# Clone repos for dev config
USER ${username}
RUN  mkdir /home/${username}/git # && cd /home/${username}/git && git clone -c "http.extraHeader=Authorization: Bearer ${git_bearer_token}" ${git_utils_repo}
USER ${username}
RUN  cd /home/${username}/git && git clone https://github.com/laminar-code/boot-dev.git 

# Link config dot files with dev config repos
USER ${username}
RUN  mkdir -p /home/${username}/.config && ln -s /home/${username}/git/boot-dev/nix/config /home/${username}/.config/nix
USER ${username}
RUN  mkdir -p /home/${username}/.config && ln -s /home/${username}/git/boot-dev/tmux /home/${username}/.config/tmux
USER ${username}
RUN  mkdir -p /home/${username}/.config && ln -s /home/${username}/git/boot-dev/nvim /home/${username}/.config/nvim
USER ${username}
RUN  mkdir -p /home/${username}/.config && ln -s /home/${username}/git/boot-dev/nix/home-manager /home/${username}/.config/home-manager

# Link ~/bin files with dev config repos
USER ${username}
RUN  mkdir /home/${username}/bin
USER ${username}
RUN  ln -s /home/${username}/git/boot-dev/git/clone /home/${username}/bin/clone
USER ${username}
RUN  ln -s /home/${username}/git/boot-dev/git/clone-files-only /home/${username}/bin/clone-files-only

# Create link for /mnt/host
USER ${username}
RUN  ln -s /mnt/host /home/${username}/host

# Copy in .env
USER ${username}
COPY --chown=${username}:${username} .env /home/${username}/.env.boot-dev

# Move .profile and .bashrc out of the way
USER ${username}
RUN  mv /home/${username}/.profile /home/${username}/.profile.orig
USER ${username}
RUN  mv /home/${username}/.bashrc /home/${username}/.bashrc.orig

# Set up nix and install home-manager
USER ${username}
RUN  curl -L https://nixos.org/nix/install | sh -s -- --no-daemon

# Paused use of Determinate Systems installer for quicker, more visible installation 
# RUN  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix > /home/${username}/nix-installer.sh
# RUN  chmod +x /home/${username}/nix-installer.sh
# RUN  /home/${username}/nix-installer.sh install linux --init none --no-confirm

# Following line is not required when running single user (--no-daemon)
# RUN  sudo chown ${username}:${username} /nix/* -R

ENV  PATH=${PATH}:/nix/var/nix/profiles/default/bin:/home/${username}/.nix-profile/bin
USER ${username}
RUN  nix-channel --add https://github.com/nixos/nixpkgs/archive/release-24.05.tar.gz nixpkgs 
RUN  nix-channel --add https://github.com/nix-community/home-manager/archive/release-24.11.tar.gz home-manager
RUN  nix-channel --update

# Configure and install home-manager and run initial home-manager switch
# This is retained for future but causes some warnings due to a release mismatch
# USER ${username}
# RUN  nix-shell '<home-manager>' -A install

USER ${username} 
RUN cd /home/${username}/.config/home-manager; nix run . -- build --impure --flake .
USER ${username} 
RUN cd /home/${username}/.config/home-manager; nix run . -- switch --impure --flake .

# Initialize Neovim plugins
USER ${username}
RUN  nvim --headless "+Lazy! sync" +qa

# Set workdir to start shell in home directory
USER    ${username}
WORKDIR /home/${username}

