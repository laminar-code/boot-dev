# boot-dev
Boot dev is a project to establish a usable development environment in a docker container with an effective tool set for command line development.

The motivation is to have a toolbox that can be easily installed and later removed without impacting the host system. There are numerous use cases surrounding ad hoc development or debugging on remote machines, where you do not want to install and configure development tools on the machine. Another set of use cases involves actual development machines where you would like to get up and running quickly with an established environment. Most tooling runs fine in a container.

## Usage

### One-liner install

Install the host dependencies (docker with the compose and buildx plugins, git, and curl) and bootstrap the .env file by running install-deps directly from the repository:

```
curl -fsSL https://raw.githubusercontent.com/laminar-code/boot-dev/main/install-deps | bash
```

For hosts without curl, wget works the same way:

```
wget -qO- https://raw.githubusercontent.com/laminar-code/boot-dev/main/install-deps | bash
```

When piped, the script fetches the repository to ~/boot-dev before running. The destination and repo can be overridden with the INSTALL_DIR and REPO_URL environment variables, e.g.:

```
curl -fsSL https://raw.githubusercontent.com/laminar-code/boot-dev/main/install-deps | INSTALL_DIR=/opt/boot-dev bash
```

The script supports apt, dnf, yum, and pacman based hosts, and verifies the required .env variables are filled in before finishing.

### Building the container

Set up the .env file according to the documentation in the .env.README template.

clean; build; run in the nix bootstrap directory will build a clean dev container based on Ubuntu 26.04.

start-dev was intended to start up the development container after it was built, but this is deprecated in favor of run which leverages docker compose to do the same thing.

go-dev logs you into the running dev container.

### Machine initialization

`init/machine-init [--user USER]` provisions a host machine for boot-dev, installing the base packages, locales, the `devx` user, nix, home-manager, and the editor and terminal configuration. The account to configure can be passed with `--user`; when it is omitted the script prompts before making any changes, using `devx` as the default.

Package management runs unattended: apt is called with `DEBIAN_FRONTEND=noninteractive`, keeps existing configuration files when a package ships a conflicting conffile (`--force-confdef --force-confold`), and runs with `NEEDRESTART_MODE=a` so needrestart does not pause for input. As a result, services affected by upgraded libraries are restarted automatically during the run. Change `NEEDRESTART_MODE` to `l` in the script to only list affected services without restarting them.

`init/flatpak-init` updates the apt package lists, installs Flatpak, adds the Flathub remote, and installs the Bazaar app store from Flathub.

At the end of the run, `machine-init` copies the invoking user's `~/.ssh/authorized_keys` into the configured account. The new `~/.ssh` directory is owned by that account with mode `0700`, and `authorized_keys` gets mode `0600`.

## Certificates

Any certificates that need to be installed into the ca bundle need to be stored in PEM format in ubuntu-nix-foundation/certs. They will be ignored by git, but will be copied into the new image and bundled with the system ca certs. 

## Security warning

The GIT_BEARER_TOKEN is passed to the container build as a docker build arg, which means it can be exposed in the image build history. This needs to be fixed so the token is not passed as a build arg.

## home-manager

Home Manager is installed by default as a flake. The current version is hard-coded to aarch64 and will need to be updated for other platforms. A new flake to handle all systems is in progress but still doesn't generically work with the home-manager switch command.

## Installed tooling

Nix for package management.

LazyVim distribution of NeoVim.

Podman for containerization.

Git of course.

Tmux for session/window management.

