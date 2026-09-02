# flake.nix
{
  description = "System-Independent Home Manager Flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    # 2.4.8 commit reference
    nixpkgs-gnupg.url = "github:NixOS/nixpkgs/a1bab9e494f5f4939442a57a58d0449a109593fe";

    home-manager = {
      # url = "github:nix-community/home-manager";
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    catppuccin.url = "github:catppuccin/nix";
    nix-flatpak.url = "github:gmodena/nix-flatpak";
    himalaya-tui.url = "github:pimalaya/himalaya-tui";

    # Utility to easily loop over multiple target systems
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, nixpkgs-gnupg, home-manager, flake-utils, ... }@inputs:
    let
      username = "devx"; # Change to your actual Ubuntu username
    in
    # This automatically generates mappings for x86_64-linux, aarch64-linux, x86_64-darwin, and aarch64-darwin
    flake-utils.lib.eachDefaultSystem (system: {
      legacyPackages = nixpkgs.legacyPackages.${system};
    }) // {
      # The homeConfigurations block sits outside the loop so Home Manager can find it,
      # but we dynamically calculate the current system architecture at runtime.
      homeConfigurations.${username} = 
        let
          # Detects the architecture of the machine running the flake command
          system = builtins.currentSystem or "aarch64-linux";
          # Overlay that pulls gnupg from the pinned revision
          gnupgOverlay = final: prev: {
            gnupg = (import nixpkgs-gnupg { inherit system; }).gnupg;
          };
          pkgs = import nixpkgs {
            inherit system;
          };
        in
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = { inherit inputs username; };
          modules = [ 
            ./home.nix 
            {
              nixpkgs.overlays = [
                (final: prev: {
                  gnupg = (import nixpkgs-gnupg { inherit system; config.allowUnfree = true; }).gnupg;
                })
              ];
            }
          ];
        };
    };
}

