{ config, pkgs, ... }: {
  home.username = "devx"; 
  home.homeDirectory = "/home/devx";
  home.stateVersion = "25.05";

  home.packages = with pkgs; [
    # Adds the 'hello' command to your environment. It prints a friendly
    # "Hello, world!" when run.
    hello

    # Networking Tools
    dnsutils
    iputils       # Need that ping
    inetutils     # whois, traceroute, et al. 
    netcat        # nc general network utility
    nettools      # More networking ifconfig, route, netstat et al.

    # Shell Tools
    direnv        # Manage environment variables per directory
    devenv        # Manage development environments
    starship      # Command prompt

    # General CLI Tools
    bat           # Much improved cat
    btop          # Much improved top
    eza           # Expanded ls
    fd            # Quick and easy find
    fzf           # Fuzzy finder
    jid           # Handy json digger
    jq            # Handy json parser
    pv            # Pipe viewer, watch that data flow
    ripgrep       # Grep tuned for git directories
    rsync         # The OG remote sync
    time          # Get time and timing of events
    unzip         # Decompression for the masses
    visidata      # Visualize data
    wget          # Get that HTTP stuff
    zip           # Compression for the masses

    # CLI Image and PDF Tools
    imagemagick
    pandoc
    qpdf
    tectonic

    # Base NeoVim Development
    # Packages for Full LazyVim
    neovim
    clojure-lsp
    lazygit
    lua
    luarocks
    nodejs_22
    nodePackages.neovim
    tree-sitter
    hadolint

    # CLI Environment Tools
    tmux          # Terminal multiplexer
    zellij        # Enhanced terminal multiplexer

    # Databases
    # NIXPKGS_ALLOW_UNFREE=1 home-manager --impure switch
    # oracle-instantclient

    # Go
    # Moved to devenv flake
    # go

    # Java/Clojure
    # Moved to devenv flake
    babashka
    clojure
    zulu

    # JavaScript
    # Moved to devenv flake
    # bun
    # pnpm

    # Python
    # Moved to devenv flake
    # (python3.withPackages (ps: with ps; [
    #  pip
    #  setuptools
    # ]))
   
    # Container Tools
    podman
    podman-compose

    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    pkgs.nerd-fonts.blex-mono

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')
  ];

  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  home.sessionPath = [ "/home/devx/bin" ];

  programs = {
    home-manager.enable = true;
    bash = {
      enable = true;
      shellAliases = {
        cls = "clear";
        vi = "nvim";
        vim = "nvim";
        docker = "podman";
        docker-compose = "podman-compose";
      };
      # TODO: figure out if this is needed in initExtra
      # . "/home/devx/.nix-profile/etc/profile.d/nix.sh"
      initExtra = ''
        . "/home/devx/.nix-profile/etc/profile.d/hm-session-vars.sh"

        eval "$(direnv hook bash)"
        eval "$(starship init bash)"

        SSH_ENV="$HOME/.ssh/agent-environment"

        function start_agent {
          echo "Initialising new SSH agent..."
          /usr/bin/ssh-agent | sed 's/^echo/#echo/' >"$SSH_ENV"
          echo succeeded
          chmod 600 "$SSH_ENV"
          . "$SSH_ENV" >/dev/null
          /usr/bin/ssh-add;
        }

        # Source SSH settings, if applicable
        if [ -f "$SSH_ENV" ]; then
          . "$SSH_ENV" >/dev/null
          #ps $SSH_AGENT_PID doesn't work under Cygwin
          ps -ef | grep $SSH_AGENT_PID | grep ssh-agent$ >/dev/null || {
            start_agent
          }
        else
          start_agent
        fi
      '';
    };
    git = {
      enable = true;
      userName = "Thomas Coffee";
      userEmail = "thms@coffee.io";
      includes = [{
        condition = "gitdir:/mnt/host/*/";
        path = "/mnt/host/git/.gitconfig-work";
      }
      {
        condition = "gitdir:~/host/*/";
        path = "/mnt/host/git/.gitconfig-work";
      }];
      extraConfig = {
        pull.rebase = false;
      };
    };
  };
}

