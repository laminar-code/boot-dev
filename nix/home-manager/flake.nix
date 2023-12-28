{
  description = "Home Manager Flake";
  
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, home-manager, ... } : 
  let
    arch = "aarch64-linux";
    allSystems = [ "x86_64-linux" "aarch64-linux" ];
    forAllSystems = f: nixpkgs.lib.genAttrs allSystems (system: f {
      pkgs = import nixpkgs { inherit system; };
    });
  in {

    packages = forAllSystems ({  pkgs } : 
    let
      homeConfigurations = {
        jcroft = 
          home-manager.lib.homeManagerConfiguration {
            inherit pkgs;
            modules = [ ./home.nix ];
          };
      };
 
      jcroft = homeConfigurations.jcroft.activationPackage;
    in {
      
      default = jcroft;

    });
  };
}

