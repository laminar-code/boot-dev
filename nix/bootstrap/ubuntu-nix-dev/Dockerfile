FROM bootstrap-dev-foundation
RUN apt-get update -y
ENV PATH="${PATH}:/nix/var/nix/profiles/default/bin"


ARG username
ARG git_bearer_token
ARG git_utils_repo


RUN adduser --shell /usr/bin/bash ${username}
ARG username=${username}
RUN addgroup ${username} sudo
ARG username=${username}
RUN addgroup ${username} sudo
RUN echo "${username} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/${username}
USER ${username}
ENV LANG en_US.utf8
ENV USER ${username}
RUN echo "${git_bearer_token}"
RUN echo "${git_utils_repo}"
USER ${username}
RUN mkdir /home/${username}/git && cd /home/${username}/git && git clone -c "http.extraHeader=Authorization: Bearer ${git_bearer_token}" ${git_utils_repo}
USER ${username}
RUN mkdir -p /home/${username}/.config/home-manager && ln -s /home/${username}/git/utils/nix/flakes/home.nix /home/${username}/.config/home-manager/home.nix
USER ${username}
RUN mkdir -p /home/${username}/.config/tmux && ln -s /home/${username}/git/utils/tmux/tmux.conf /home/${username}/.config/tmux/tmux.conf
USER ${username}
RUN mkdir -p /home/${username}/.config/nvim && ln -s /home/${username}/git/utils/nvim/init.lua /home/${username}/.config/nvim/init.lua
USER ${username}
RUN sudo chown --recursive ${username} /nix
USER ${username}
RUN sudo /root/.nix-profile/bin/nix-daemon & sleep 1 & nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
USER ${username}
RUN sudo /root/.nix-profile/bin/nix-daemon & sleep 1 & nix-channel --update
USER ${username}
RUN sudo /root/.nix-profile/bin/nix-daemon & sleep 1 & mv /home/${username}/.bashrc /home/${username}/.bashrc.orig & mv /home/${username}/.profile /home/${username}/.profile.orig & USER=${username} nix-shell '<home-manager>' -A install
USER ${username} 
RUN sudo /root/.nix-profile/bin/nix-daemon & sleep 1 & USER=${username} /home/${username}/.nix-profile/bin/home-manager switch -b backup


USER ${USERNAME}
WORKDIR /home/${username}

