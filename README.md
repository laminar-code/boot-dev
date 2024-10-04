# boot-dev

Boot dev is a project to establish a usable development environment in a docker container with an effective tool set for command line development.

The motivation is to have a toolbox that can be easily installed and later removed without impacting the host system. There are numerous use cases surrounding ad hoc development or debugging on remote machines, where you do not want to install and configure development tools on the machine. Another set of use cases involves actual development machines where you would like to get up and running quickly with an established environment. Most tooling runs fine in a container.

## Usage

Set up the .env file according to the documentation in the .env.README template.

clean; build; run in the nix bootstrap directory will build a clean dev container based on Ubuntu 24.04.

start-dev was intended to start up the development container after it was built, but this is deprecated in favor of run which leverages docker compose to do the same thing.

go-dev logs you into the running dev container.

## Installed tooling

Nix for package management.

LazyVim distribution of NeoVim.

Podman for containerization.

Git of course.

Tmux for session/window management.

