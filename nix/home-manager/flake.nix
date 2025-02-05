
{
  description = "Home Manager Flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/release-24.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... } : let
    system = "aarch64-linux";
    user = "devx";
    pkgs = import nixpkgs { inherit system; };
  in {
    defaultPackage.${system} =
      home-manager.defaultPackage.${system};

    homeConfigurations = {
      ${user} = home-manager.lib.homeManagerConfiguration {
        pkgs = pkgs;
        modules = [ ./home.nix ];
      };
    };
  };
}

