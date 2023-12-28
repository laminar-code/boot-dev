FROM ubuntu-nix-foundation

# Set PATH in environment
ENV PATH="${PATH}:/nix/var/nix/profiles/default/bin"

# Declare args
ARG username
ARG git_bearer_token
ARG git_utils_repo

# Set up local user and add to sudoers w/o password requirement
RUN adduser --shell /usr/bin/bash ${username}
ARG username=${username}
RUN addgroup ${username} sudo
RUN echo "${username} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/${username}

# Set LANG and USER in user environment
USER ${username}
ENV LANG en_US.utf8
ENV USER ${username}

# Clone repos for dev config
USER ${username}
RUN mkdir /home/${username}/git && cd /home/${username}/git && git clone -c "http.extraHeader=Authorization: Bearer ${git_bearer_token}" ${git_utils_repo}
USER ${username}
RUN cd /home/${username}/git && git clone https://github.com/laminar-code/boot-dev.git 

# Link config dot files with dev config repos
USER ${username}
RUN mkdir -p /home/${username}/.config/nix &&  ln -s /home/${username}/git/boot-dev/nix/config/nix.conf /home/${username}/.config/nix/nix.conf
USER ${username}
RUN mkdir -p /home/${username}/.config &&      ln -s /home/${username}/git/boot-dev/nix/nixpkgs /home/${username}/.config/nixpkgs
USER ${username}
RUN mkdir -p /home/${username}/.config &&      ln -s /home/${username}/git/boot-dev/nix/home-manager /home/${username}/.config/home-manager
USER ${username}
RUN mkdir -p /home/${username}/.config/tmux && ln -s /home/${username}/git/boot-dev/tmux/tmux.conf /home/${username}/.config/tmux/tmux.conf
USER ${username}
RUN mkdir -p /home/${username}/.config/nvim && ln -s /home/${username}/git/boot-dev/nvim/init.lua /home/${username}/.config/nvim/init.lua

# Link ~/bin files with dev config repos
USER ${username}
RUN mkdir /home/${username}/bin
USER ${username}
RUN ln -s /home/${username}/git/boot-dev/git/clone /home/${username}/bin/clone
USER ${username}
RUN ln -s /home/${username}/git/boot-dev/git/clone-files-only /home/${username}/bin/clone-files-only

# Copy in .env
USER ${username}
COPY --chown=${username}:${username} .env /home/${username}/.env.boot-dev

# Update permissions on nix store to prevent podman error message
RUN sudo chown --recursive ${username} /nix
USER ${username}

# Configure and install home-manager and run initial home-manager switch
# RUN sudo /root/.nix-profile/bin/nix-daemon & sleep 1 && nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
# USER ${username}
# RUN sudo /root/.nix-profile/bin/nix-daemon & sleep 1 && nix-channel --update
# USER ${username}
# RUN sudo /root/.nix-profile/bin/nix-daemon & sleep 1 && mv /home/${username}/.bashrc /home/${username}/.bashrc.orig && mv /home/${username}/.profile /home/${username}/.profile.orig && USER=${username} nix-shell '<home-manager>' -A install
# USER ${username} 
# RUN sudo /root/.nix-profile/bin/nix-daemon & sleep 1 && USER=${username} /home/${username}/.nix-profile/bin/home-manager switch -b backup
USER ${username} 
RUN { sudo /root/.nix-profile/bin/nix-daemon & } && sleep 1 && cd /home/${username}/.config/home-manager && nix run . switch

# Set workdir to start shell in home directory
USER ${username}
WORKDIR /home/${username}

