{ config, pkgs, ... }: {
  home.username = "jcroft"; 
  home.homeDirectory = "/home/jcroft";
  home.stateVersion = "23.11";

  home.packages = with pkgs; [
    # # Adds the 'hello' command to your environment. It prints a friendly
    # # "Hello, world!" when run.
    hello

    iputils

    babashka
    bat
    btop
    fd
    fzf
    ripgrep
    rsync

    unzip
    wget
    zip

    git
    gitui
    lazygit
    tmux

    clojure
    gcc
    lua
    nodejs_18
    python39
    zulu

    clojure-lsp
    luarocks
    tree-sitter
    nodePackages.neovim

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

    # "bin/docker".source = config.lib.file.mkOutOfStoreSymlink "/home/jcroft/.nix-profile/bin/podman";
  };

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  home.sessionPath = [ "/home/jcroft/bin" ];

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
        . "/home/jcroft/.nix-profile/etc/profile.d/hm-session-vars.sh"
      '';
    };
    git = {
      enable = true;
      userName = "John Croft";
      userEmail = "jcroft@coderz.io";
      extraConfig = {
        pull.rebase = false;
      };
    };
  };
}

