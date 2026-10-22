{ pkgs, inputs, username, lib, ... }:
let 
  homeDir = if pkgs.stdenv.hostPlatform.isDarwin then "/Users/${username}" else "/home/${username}";

  # ---------------------------------------------------------------------------
  # Vivaldi browser extensions
  #
  # Vivaldi is managed as a *user* flatpak (nix-flatpak hardcodes
  # `installation = "user"`), so the browser executable does not live in the
  # Nix store but inside the flatpak deployment:
  #
  #   ~/.local/share/flatpak/app/com.vivaldi.Vivaldi/<arch>/stable/active/files/vivaldi/
  #
  # Chromium/Vivaldi pick up "external extensions" from an `extensions/`
  # directory that sits next to the browser executable.  Every extension is
  # described by a `<extension-id>.json` file; the browser then downloads the
  # add-on itself from `update_url` the first time it starts, which means the
  # extension is in place right after the very first launch.
  # ---------------------------------------------------------------------------
  vivaldiAppId = "com.vivaldi.Vivaldi";

  # Flatpak names deployments after the runtime architecture (`aarch64`,
  # `x86_64`); Nix's `parsed.cpu.name` uses the exact same spelling.
  vivaldiArch = pkgs.stdenv.hostPlatform.parsed.cpu.name;

  # Root of the Vivaldi deployment inside the user flatpak installation.
  vivaldiFlatpakDir = "${homeDir}/.local/share/flatpak/app/${vivaldiAppId}";

  # Flatpak repoints `<arch>/stable/active` whenever the app is updated,
  # which invalidates every file we drop into the deployment.
  vivaldiStableDir = "${vivaldiFlatpakDir}/${vivaldiArch}/stable";

  # Update server the browser uses to download the extension payload.
  crxUpdateUrl = "https://clients2.google.com/service/update2/crx";

  # The Chrome Web Store ids of the extensions we want to have installed.
  vivaldiExtensions = [
    {
      id = "bfogiafebfohielmmehodmfbbebbbpei";
      name = "keeper-security";
    }
    {
      id = "ldgfbffkinooeloadekpmfoklnobpien";
      name = "raindrop-io";
    }
  ];

  vivaldiExtensionDefinitions = map (ext: {
    # The file name has to be the extension id, that is how Chromium
    # associates the definition with the add-on.
    file = "${ext.id}.json";
    source = pkgs.writeText "${ext.name}.json" (builtins.toJSON {
      external_update_url = crxUpdateUrl;
      extension = {
        id = ext.id;
        update_url = crxUpdateUrl;
      };
    });
  }) vivaldiExtensions;

  # The `install` invocations that copy a definition into the target
  # directory.  The indentation is part of the string so that the generated
  # script stays readable.
  vivaldiExtensionInstalls = lib.concatStringsSep "\n" (map (ext:
    "    install -m 0644 \"${ext.source}\" \"$target/${ext.file}\""
  ) vivaldiExtensionDefinitions);

  # Drop the declarative definitions into every Vivaldi deployment of the user
  # flatpak installation.
  vivaldiExtensionSync = pkgs.writeShellApplication {
    name = "vivaldi-extension-sync";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      app_dir="${vivaldiFlatpakDir}"

      shopt -s nullglob
      deployments=("$app_dir"/*/stable/active)
      shopt -u nullglob

      if [ ''${#deployments[@]} -eq 0 ]; then
        echo "vivaldi-extension-sync: no Vivaldi deployment below $app_dir" >&2
        exit 0
      fi

      for deployment in "''${deployments[@]}"; do
        [ -d "$deployment" ] || continue
        target="$deployment/files/vivaldi/extensions"
        mkdir -p "$target"

        # This directory is fully managed by this configuration, so drop
        # definitions that are no longer part of it.
        rm -f -- "$target"/*.json

      ${vivaldiExtensionInstalls}
      done
    '';
  };
in
{
  home.username = username; 
  home.stateVersion = "25.05";
  # home.homeDirectory = "/home/devx";
  # Dynamically sets the home directory path based on the OS architecture string
  home.homeDirectory = homeDir;

  fonts.fontconfig.enable = true;

  targets.genericLinux.enable = true;
  xdg.enable = true;

  imports = [
    # inputs.zen-browser.homeModules.beta
    # inputs.zen-browser.homeModules.twilight
    # inputs.zen-browser.homeModules.twilight-official
    inputs.catppuccin.homeModules.catppuccin
    inputs.nix-flatpak.homeManagerModules.nix-flatpak
  ];

  home.packages = with pkgs; [
    # Adds the 'hello' command to your environment. It prints a friendly
    # "Hello, world!" when run.
    hello

    # Intallation platforms
    # flatpak # Installed at system level due to apparmor

    # Networking Tools
    dnsutils
    iputils       # Need that ping
    inetutils     # whois, traceroute, et al. 
    netcat        # nc general network utility
    nettools      # More networking ifconfig, route, netstat et al.

    # Shell Tools
    direnv        # Manage environment variables per directory
    devenv        # Manage development environments
    ghostty	  # Cross-platform terminal emulator
    starship      # Command prompt

    # Security Tools
    gnupg         # Pretty Good Privacy
    pass          # Password/secrets managment

    # General CLI Tools
    bat             # Much improved cat
    btop            # Much improved top
    catppuccin      # Terminal theme
    eza             # Expanded ls
    fd              # Quick and easy find
    fzf             # Fuzzy finder
    jid             # Handy json digger
    jq              # Handy json parser
    magic-wormhole  # P2P secure file transfer
    nfpm            # Package building tool
    pv              # Pipe viewer, watch that data flow
    ripgrep         # Grep tuned for git directories
    rsync           # The OG remote sync
    s3cmd           # S3 file storage tool
    time            # Get time and timing of events
    unzip           # Decompression for the masses
    visidata        # Visualize data
    wget            # Get that HTTP stuff
    zip             # Compression for the masses

    # Email
    himalaya        # CLI email client
    inputs.himalaya-tui.packages.${pkgs.stdenv.hostPlatform.system}.default # TUI for himalaya

    # CLI Image and PDF Tools
    imagemagick
    pandoc
    qpdf
    tectonic
    zint-qt         # Encode data into barcodes
    timg            # Terminal image viewer

    # Base NeoVim Development
    # Packages for Full LazyVim
    neovim
    clojure-lsp
    lazygit
    lua
    luarocks
    nodejs_22
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
    # babashka
    # clojure
    # zulu

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

    #UI Apps
    warp

    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    pkgs.nerd-fonts.blex-mono
    pkgs.nerd-fonts.jetbrains-mono

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

  catppuccin = {
    enable = true;
    autoEnable = true;
  };

  # Configure Servicies
  services = {
    flatpak = {
      enable = true;

      # Automatically add the Flathub remote repository if missing
      remotes = [{
        name = "flathub";
        location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
      }];

      # Declare the packages you want to install
      packages = [
        "app.zen_browser.zen"
        "com.vivaldi.Vivaldi"
      ];

      # Optional: Automatically update packages on activation
      update.auto.enable = true;
    };
    gpg-agent = {
      enable = true;
      enableSshSupport = true;
    
      # Explicitly pick a pinentry package matching your desktop environment 
      # (e.g., pinentry-gnome3, pinentry-qt, pinentry-curses)
      pinentry.package = pkgs.pinentry-curses; # Use pinentry-qt or pinentry-gnome3 if you have a GUI
    
      extraConfig = ''
        allow-loopback-pinentry
      '';
    };
  };

  # Install the Vivaldi extensions into the flatpak deployment and keep them
  # there.  Flatpak replaces the whole deployment on every update, so the
  # definitions have to be copied again afterwards.
  systemd.user.services.vivaldi-extension-sync = {
    Unit = {
      Description = "Install declarative Vivaldi browser extensions";
      # The flatpak has to be present before we can write into its deployment.
      After = [ "flatpak-managed-install.service" ];
      Wants = [ "flatpak-managed-install.service" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${vivaldiExtensionSync}";
    };
    Install.WantedBy = [ "default.target" ];
  };

  systemd.user.paths.vivaldi-extension-sync = {
    Unit = {
      Description = "Watch the Vivaldi flatpak deployment for changes";
    };
    Path = {
      # The stable directory is created when the flatpak is installed and
      # modified whenever flatpak deploys a new revision of the application.
      # Watching it therefore covers both the first installation and every
      # later update.  `PathExists=` must not be used here: it re-triggers
      # the unit in a loop as soon as the path is there.
      PathChanged = "${vivaldiStableDir}";
      Unit = "vivaldi-extension-sync.service";
    };
    Install.WantedBy = [ "default.target" ];
  };

  # Configure Programs
  programs = {
    home-manager = {
      enable = true;
    };
    bash = {
      enable = true;
      shellAliases = {
        cls = "clear";
        vi = "nvim";
        vim = "nvim";
        docker = "podman";
        docker-compose = "podman-compose";
        hm-switch = "home-manager switch --impure --flake ~/.config/home-manager#${username}";
      };
      initExtra = ''
        # Initialize nix environment
	if [ -e ~/.nix-profile/etc/profile.d/hm-session-vars.sh ]; then
	  . ~/.nix-profile/etc/profile.d/hm-session-vars.sh
	fi
         if [ -e ~/.nix-profile/etc/profile.d/nix.sh ]; then
	  . ~/.nix-profile/etc/profile.d/nix.sh
	fi
        
	eval "$(direnv hook bash)"
        eval "$(starship init bash)"

	# Point SSH to the GPG Agent socket
	export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)

	# Ensure GPG can prompt for passphrases correctly in the current terminal
	export GPG_TTY=$(tty)
	gpg-connect-agent updatestartuptty /bye >/dev/null

        # Use gpg-agent as the SSH agent (requires enable-ssh-support in gpg-agent.conf)
        gpgconf --launch gpg-agent
      '';
    };
    git = {
      enable = true;
      includes = [{
        condition = "gitdir:/mnt/host/*/";
        path = "/mnt/host/git/.gitconfig-work";
      }
      {
        condition = "gitdir:~/host/*/";
        path = "/mnt/host/git/.gitconfig-work";
      }];
      settings = {
        user = {
      	  name = "Thomas Coffee";
      	  email = "thms@coffee.io";
	      };
	      pull = {
      	  rebase = false;
    	  };
      };
    };
    gpg = {
      enable = true;
      package = pkgs.gnupg;
    };
    himalaya = {
      enable = true;
    };
    ghostty = {
      enable = true;
    };
    # zen-browser = {
    #   enable = true;
    #   setAsDefaultBrowser = true;
    # };
  };
}

