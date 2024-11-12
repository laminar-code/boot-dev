{ config, pkgs, ... }: {
  home.username = "devx"; 
  home.homeDirectory = "/home/devx";
  home.stateVersion = "24.05";

  home.packages = with pkgs; [
    # Adds the 'hello' command to your environment. It prints a friendly
    # "Hello, world!" when run.
    hello

    # Networking Tools
    iputils       # Need that ping
    netcat        # Netcat

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
    unzip         # Decompression for the masses
    visidata      # Visualize data
    wget          # Get that HTTP stuff
    zip           # Compression for the masses

    # Base NeoVim Development
    # Packages for Full LazyVim
    clojure-lsp
    lazygit
    lua
    luarocks
    nodejs_22
    nodePackages.neovim
    tree-sitter

    # CLI Environment Tools
    tmux          # Terminal multiplexer
    
    # Java/Clojure
    # babashka
    # clojure
    # zulu

    # Python
    # python39
   
    # Container Tools
    podman
    podman-compose

    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    (pkgs.nerdfonts.override { fonts = [ "IBMPlexMono" ]; })

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

    # "bin/docker".source = config.lib.file.mkOutOfStoreSymlink "/home/$USER/.nix-profile/bin/podman";
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
      };
      initExtra = ''
        . "/home/devx/.nix-profile/etc/profile.d/nix.sh"
        . "/home/devx/.nix-profile/etc/profile.d/hm-session-vars.sh"

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
        condition = "gitdir:~/host/*/";
        path = "~/host/git/.gitconfig-work";
      }];
      extraConfig = {
        pull.rebase = false;
      };
    };
  };
}

