{ pkgs, inputs, username, lib, ... }:
let 
  homeDir = if pkgs.stdenv.hostPlatform.isDarwin then "/Users/${username}" else "/home/${username}";

  # ---------------------------------------------------------------------------
  # Vivaldi browser extensions
  #
  # Vivaldi is managed as a *user* flatpak (nix-flatpak hardcodes
  # `installation = "user"`). Chromium/Vivaldi pick up "external extensions"
  # from an `extensions/` directory next to the browser executable.
  # ---------------------------------------------------------------------------
  vivaldiAppId = "com.vivaldi.Vivaldi";
  vivaldiArch = pkgs.stdenv.hostPlatform.parsed.cpu.name;
  vivaldiFlatpakDir = "${homeDir}/.local/share/flatpak/app/${vivaldiAppId}";

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
    file = "${ext.id}.json";
    source = pkgs.writeText "${ext.name}.json" (builtins.toJSON {
      external_update_url = crxUpdateUrl;
      extension = {
        id = ext.id;
        update_url = crxUpdateUrl;
      };
    });
  }) vivaldiExtensions;

  # Script to install extensions into all current deployments
  vivaldiExtensionInstallScript = pkgs.writeShellScript "vivaldi-extension-install" ''
    app_dir="${vivaldiFlatpakDir}"
    shopt -s nullglob
    deployments=("$app_dir"/*/stable/active)
    shopt -u nullglob

    if [ ''${#deployments[@]} -eq 0 ]; then
      exit 0
    fi

    for deployment in "''${deployments[@]}"; do
      [ -d "$deployment" ] || continue
      target="$deployment/files/vivaldi/extensions"
      mkdir -p "$target"
      rm -f -- "$target"/*.json
      ${lib.concatStringsSep "\n" (map (ext: "      install -m 0644 \"${ext.source}\" \"$target/${ext.file}\"") vivaldiExtensionDefinitions)}
    done
  '';

  # One-time onboarding flags. The Vivaldi setup wizard is gated by
  # `vivaldi.startup.has_seen_welcome_page` (native, not `vivaldi.first_run`),
  # and the Chromium welcome tab by `browser.has_seen_welcome_page`.
  # `vivaldi.welcome.read_pages` is the per-page progress list used by the
  # wizard, seeded with every page so it never restarts mid-flow.
  vivaldiOnboardingPrefs = {
    browser = {
      check_default_browser = false;
      has_seen_welcome_page = true;
    };
    vivaldi = {
      startup = {
        has_seen_welcome_page = true;
      };
      welcome = {
        read_pages = [
          "intro"
          "a11y_settings"
          "account"
          "control"
          "import_data"
          "tracker_and_ad"
          "layouts"
          "personalize"
          "panel_internal"
          "panel_apps"
          "welcome_feature_amount"
          "mail_setup"
        ];
      };
    };
  };

  vivaldiOnboardingPrefsFile = pkgs.writeText "vivaldi-onboarding-prefs"
    (builtins.toJSON vivaldiOnboardingPrefs);

  # Merge the onboarding flags into a profile Vivaldi has already initialised.
  # Without this, seeding only works on a profile that does not exist yet.
  vivaldiSeedPrefs = pkgs.writeScript "vivaldi-seed-prefs" ''
    #!${pkgs.python3}/bin/python3
    import json
    import os
    import sys
    import tempfile

    prefs_path, defaults_path = sys.argv[1], sys.argv[2]

    try:
        with open(prefs_path) as fh:
            prefs = json.load(fh)
    except (OSError, ValueError):
        sys.exit(0)

    startup = prefs.setdefault("vivaldi", {}).setdefault("startup", {})
    if startup.get("has_seen_welcome_page") is True:
        # User (or a previous run) already completed the wizard; do not touch it.
        sys.exit(0)

    with open(defaults_path) as fh:
        defaults = json.load(fh)

    def merge(dst, src):
        for key, value in src.items():
            if isinstance(value, dict) and isinstance(dst.get(key), dict):
                merge(dst[key], value)
            elif isinstance(value, list) and isinstance(dst.get(key), list):
                for item in value:
                    if item not in dst[key]:
                        dst[key].append(item)
            else:
                dst[key] = value

    merge(prefs, defaults)

    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(prefs_path), prefix=".Preferences.")
    with os.fdopen(fd, "w") as fh:
        json.dump(prefs, fh)
    os.replace(tmp, prefs_path)
  '';

  # Default Vivaldi preferences to skip first-run/setup wizards
  vivaldiDefaultPreferences = pkgs.writeText "vivaldi-default-preferences" (builtins.toJSON (vivaldiOnboardingPrefs // {
    distribution = {
      import_bookmarks = false;
      import_bookmarks_from_file = "";
      import_history = false;
      import_search_engine = false;
      skip_first_run_ui = true;
    };
    first_run_tabs = [ ];
    homepage = "about:blank";
    homepage_is_newtabpage = false;
    session = {
      restore_on_startup = 1;
      startup_urls = [ "about:blank" ];
    };
    sync = {
      suppress_startup_sync_promos = true;
    };
  }));

  # Local State to skip first run
  vivaldiLocalState = pkgs.writeText "vivaldi-local-state" (builtins.toJSON {
    browser = {
      enabled_labs_experiments = [];
    };
    profile = {
      info_cache = { };
    };
    shutdown = { };
  });

  # ---------------------------------------------------------------------------
  # Zen browser extensions and startup defaults
  #
  # Zen is Firefox-based and reads enterprise policies from
  # `$SysConfD/policies/policies.json`. The Zen flatpak maps its
  # `app.zen_browser.zen.systemconfig` extension point to `/app/etc/zen`, and
  # user-installed extensions are honoured even for a system-installed flatpak.
  # That makes the policy path writable without root:
  #   ~/.local/share/flatpak/extension/app.zen_browser.zen.systemconfig/<arch>/stable
  #
  # Policies install the extensions and suppress Firefox's first-run and
  # post-update pages. Zen's own welcome screen is gated by the `zen.` pref
  # namespace, which the policy `Preferences` block does not allow, so that
  # flag is seeded into the profile instead (prefs.js for a new profile,
  # user.js for profiles that already exist).
  # ---------------------------------------------------------------------------
  zenAppId = "app.zen_browser.zen";
  zenArch = pkgs.stdenv.hostPlatform.parsed.cpu.name;
  zenSystemConfigDir = "${homeDir}/.local/share/flatpak/extension/${zenAppId}.systemconfig/${zenArch}/stable";
  zenProfileRoot = "${homeDir}/.var/app/${zenAppId}/.zen";

  zenExtensions = [
    {
      id = "KeeperFFStoreExtension@KeeperSecurityInc";
      slug = "keeper-password-manager";
    }
    {
      id = "jid0-adyhmvsP91nUO8pRv0Mn2VKeB84@jetpack";
      slug = "raindropio";
    }
  ];

  zenExtensionSettings = builtins.listToAttrs (map (ext: {
    name = ext.id;
    value = {
      installation_mode = "force_installed";
      install_url = "https://addons.mozilla.org/firefox/downloads/latest/${ext.slug}/latest.xpi";
    };
  }) zenExtensions);

  zenPolicies = {
    policies = {
      DisableAppUpdate = true;
      DontCheckDefaultBrowser = true;
      OverrideFirstRunPage = "";
      OverridePostUpdatePage = "";
      DisableTelemetry = true;
      ExtensionSettings = zenExtensionSettings;
      Preferences = {
        # Zen already defaults to restoring the previous session; pin it so
        # startup behaviour does not depend on profile state.
        "browser.startup.page" = {
          Value = 3;
          Status = "default";
        };
        "browser.startup.firstrunSkipsHomepage" = {
          Value = true;
          Status = "default";
        };
        # `OverrideFirstRunPage` already disables this; keep it explicit.
        "browser.aboutwelcome.enabled" = {
          Value = false;
          Status = "default";
        };
      };
    };
  };

  zenPoliciesFile = pkgs.writeText "zen-policies.json" (builtins.toJSON zenPolicies);

  # `user.js` is re-applied on every start, so this stays effective even on a
  # profile that was created before this configuration existed.
  zenUserJs = pkgs.writeText "zen-user.js" ''
    // Managed by home-manager: skip Zen's first-run welcome screen.
    user_pref("zen.welcome-screen.seen", true);
  '';

  zenSetupScript = pkgs.writeShellScript "zen-setup" ''
    set -eu

    # Install the enterprise policy. Inside the sandbox Zen reads it from
    # /app/etc/zen/policies/policies.json.
    policies_dir="${zenSystemConfigDir}/policies"
    mkdir -p "$policies_dir"
    install -m 0644 "${zenPoliciesFile}" "$policies_dir/policies.json"

    profile_root="${zenProfileRoot}"
    mkdir -p "$profile_root"

    # Find the installed Zen build. The welcome screen normally records the
    # build/version prefs while it runs; because we skip it, seed them into a
    # fresh profile so the first start does not report a phantom update.
    app_ini=""
    for candidate in \
      "${homeDir}/.local/share/flatpak/app/${zenAppId}/current/active/files/zen/application.ini" \
      "/var/lib/flatpak/app/${zenAppId}/current/active/files/zen/application.ini"; do
      if [ -f "$candidate" ]; then
        app_ini="$candidate"
        break
      fi
    done
    app_version=""
    app_build_id=""
    if [ -n "$app_ini" ]; then
      app_version=$(sed -n 's/^Version=//p' "$app_ini" | head -n 1)
      app_build_id=$(sed -n 's/^BuildID=//p' "$app_ini" | head -n 1)
    fi

    # Seed a default profile before the first launch. Without a profiles.ini
    # Firefox invents a profile after activation has already run, so the
    # welcome flag would be missing on the very first start.
    if [ ! -f "$profile_root/profiles.ini" ]; then
      mkdir -p "$profile_root/zen.default"
      {
        echo '// Managed by home-manager: skip Zen first-run welcome screen.'
        echo 'user_pref("zen.welcome-screen.seen", true);'
        if [ -n "$app_version" ] && [ -n "$app_build_id" ]; then
          printf 'user_pref("zen.updates.last-version", "%s");\n' "$app_version"
          printf 'user_pref("zen.updates.last-build-id", "%s");\n' "$app_build_id"
        fi
      } > "$profile_root/zen.default/prefs.js"
      cat > "$profile_root/profiles.ini" <<'EOF'
    [Profile0]
    Name=default
    IsRelative=1
    Path=zen.default
    Default=1

    [General]
    StartWithLastProfile=1
    Version=2
    EOF
    fi

    # Profiles created before this configuration still need the flag. Merge it
    # instead of replacing an existing user.js on the user's behalf.
    for profile in "$profile_root"/*/; do
      [ -d "$profile" ] || continue
      case "$(basename "$profile")" in
        "Profile Groups") continue ;;
      esac
      if [ -f "$profile/times.json" ] || [ -f "$profile/prefs.js" ] || [ -f "$profile/compatibility.ini" ]; then
        if [ ! -f "$profile/user.js" ]; then
          install -m 0644 "${zenUserJs}" "$profile/user.js"
        elif ! grep -q 'zen\.welcome-screen\.seen' "$profile/user.js"; then
          printf '\n' >> "$profile/user.js"
          cat "${zenUserJs}" >> "$profile/user.js"
        fi
      fi
    done
  '';
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

  # Install Vivaldi extensions and pre-seed default settings for first run
  home.activation.vivaldiSetup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # Install extensions
    if [ -x "${vivaldiExtensionInstallScript}" ]; then
      "${vivaldiExtensionInstallScript}" || true
    fi

    # Pre-seed Vivaldi profile with default settings to skip first-run prompts
    VIVALDI_CONFIG="${homeDir}/.var/app/com.vivaldi.Vivaldi/config/vivaldi"
    mkdir -p "$VIVALDI_CONFIG" "$VIVALDI_CONFIG/Default"

    # Copy default preferences if they don't exist or to reset to defaults
    if [ ! -f "$VIVALDI_CONFIG/Default/Preferences" ] || [ -n "''${VIVALDI_RESET_PREFS:-}" ]; then
      cp "${vivaldiDefaultPreferences}" "$VIVALDI_CONFIG/Default/Preferences" 2>/dev/null || true
    fi

    # Set Local State to skip first run
    if [ ! -f "$VIVALDI_CONFIG/Local State" ] || [ -n "''${VIVALDI_RESET_PREFS:-}" ]; then
      cp "${vivaldiLocalState}" "$VIVALDI_CONFIG/Local State" 2>/dev/null || true
    fi

    # Profiles created before the onboarding flags were correct still have the
    # wizard pending. Patch them in place (Vivaldi rewrites Preferences on exit,
    # so only do this while it is not running).
    VIVALDI_RUNNING=0
    ${lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
      if ${pkgs.procps}/bin/pgrep -f '/app/vivaldi/vivaldi' >/dev/null 2>&1 \
        || ${pkgs.procps}/bin/pgrep -x vivaldi >/dev/null 2>&1; then
        VIVALDI_RUNNING=1
      fi
    ''}
    if [ -f "$VIVALDI_CONFIG/Default/Preferences" ] && [ "$VIVALDI_RUNNING" -eq 0 ]; then
      "${vivaldiSeedPrefs}" \
        "$VIVALDI_CONFIG/Default/Preferences" \
        "${vivaldiOnboardingPrefsFile}" || true
    fi
  '';

  # Install Zen enterprise policies (extensions + startup) and seed the
  # profile flag that disables Zen's own welcome screen
  home.activation.zenSetup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -x "${zenSetupScript}" ]; then
      "${zenSetupScript}" || true
    fi
  '';

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

