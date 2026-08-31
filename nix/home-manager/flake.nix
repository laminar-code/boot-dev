# flake.nix
{
  description = "System-Independent Home Manager Flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Utility to easily loop over multiple target systems
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, home-manager, flake-utils, ... }:
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
          system = builtins.currentSystem or "x86_64-linux"; 
          pkgs = nixpkgs.legacyPackages.${system};
        in
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [ ./home.nix ];
          extraSpecialArgs = { inherit username system; };
        };
    };
}

