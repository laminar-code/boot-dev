FROM ubuntu-nix-foundation

# Declare args
ARG username
ARG git_bearer_token
ARG git_utils_repo
ARG DEBIAN_FRONTEND=noninteractive

# Set up local user and add to sudoers w/o password requirement
RUN  adduser --shell /usr/bin/bash ${username}
RUN  groupadd -g 9999 devs
# ARG  username=${username}
RUN  usermod -a -G devs ${username}
RUN  adduser ${username} sudo
RUN  echo "${username} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/${username}

# Add .ssh config to user
COPY .build/.ssh/.placeholder .build/.ssh/ /home/${username}/.ssh/
RUN  chown -R ${username}:${username} /home/${username}/.ssh
RUN  find /home/${username}/.ssh -type f -exec chmod 600 {} +
RUN  find /home/${username}/.ssh -type d -exec chmod 700 {} +

# Set LANG and USER in user environment
USER ${username}
ENV LANG=en_US.utf8
ENV USER=${username}

# Clone repos for dev config
USER ${username}
RUN  mkdir /home/${username}/git
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
USER ${username}
RUN  mkdir -p /home/${username}/.config && ln -s /home/${username}/git/boot-dev/lazygit /home/${username}/.config/lazygit

# Link ~/bin files with dev config repos
USER ${username}
RUN  mkdir /home/${username}/bin
USER ${username}
RUN  ln -s /home/${username}/git/boot-dev/git/clone /home/${username}/bin/clone
USER ${username}
RUN  ln -s /home/${username}/git/boot-dev/git/clone-files-only /home/${username}/bin/clone-files-only
USER ${username}
RUN  ln -s /home/${username}/git/boot-dev/git/switch-origin /home/${username}/bin/switch-origin
USER ${username}
RUN  ln -s /home/${username}/git/boot-dev/nix/bin/dev /home/${username}/bin/dev

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
RUN  nix-channel --add https://github.com/nixos/nixpkgs/archive/nixpkgs-unstable.tar.gz nixpkgs 
RUN  nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
RUN  nix-channel --update

# Configure and install home-manager and run initial home-manager switch
# This is retained for future but causes some warnings due to a release mismatch
USER ${username}
RUN  nix-shell '<home-manager>' -A install

# Link to devenv flake
USER ${username}
RUN ln -s /home/${username}/git/boot-dev/nix/devenv /home/${username}/devenv

# Initialize Neovim plugins
USER ${username}
RUN  nvim --headless "+Lazy! sync" +qa

# Set workdir to start shell in home directory
USER    ${username}
WORKDIR /home/${username}

