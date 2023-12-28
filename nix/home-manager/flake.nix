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

  outputs = inputs@{ self, nixpkgs, flake-utils, home-manager, ... } : 
  let
    arch = "aarch64-linux";
  in {

    homeConfigurations = {
      jcroft = 
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${arch};
          modules = [ ./home.nix ];
        };
    };
  
    jcroft = self.homeConfigurations.jcroft.activationPackage;
    defaultPackage.${arch} = self.jcroft;

  };

#  outputs = { self, nixpkgs, flake-utils, home-manager, ... }:
#    # calling a function from `flake-utils` that takes a lambda
#    # that takes the system we're targetting
#    flake-utils.lib.eachDefaultSystem (system:
#      let
#        # no need to define `system` anymore
#        name = "home-manager";
#        src = ./.;
#        pkgs = nixpkgs.legacyPackages.${system};
#      in
#      {
#        # `eachDefaultSystem` transforms the input, our output set
#        # now simply has `packages.default` which gets turned into
#        # `packages.${system}.default` (for each system)
#        packages.default = derivation {
#          inherit system name src;
#          builder = with pkgs; "${bash}/bin/bash";
#          args = [ "-c" "echo hello > $out" ];
#        };
#
#        homeConfigurations.jcroft = 
#          home-manager.lib.homeManagerConfiguration {
#            inherit pkgs;
#            modules = [ ./home.nix ];
#          };
#      }
#    );
}

