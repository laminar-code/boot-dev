
{
  description = "Home Manager Flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... } : let
    system = "x86_64-linux";
    user = "devx";
    pkgs = import nixpkgs { inherit system; };
  in {
    # defaultPackage.${system} =
    #   home-manager.defaultPackage.${system};

    homeConfigurations = {
      ${user} = home-manager.lib.homeManagerConfiguration {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        # pkgs = pkgs;
        modules = [ ./home.nix ];
      };
    };
  };

  # outputs = inputs@{ nixpkgs, home-manager, ... }: {
  #   nixosConfigurations = {
  #     # TODO please change the hostname to your own
  #     my-nixos = nixpkgs.lib.nixosSystem {
  #       system = "x86_64-linux";
  #       modules = [
  #         ./configuration.nix

  #         # make home-manager as a module of nixos
  #         # so that home-manager configuration will be deployed automatically when executing `nixos-rebuild switch`
  #         home-manager.nixosModules.home-manager
  #         {
  #           home-manager.useGlobalPkgs = true;
  #           home-manager.useUserPackages = true;

  #           # TODO replace ryan with your own username
  #           home-manager.users.ryan = import ./home.nix;

  #           # Optionally, use home-manager.extraSpecialArgs to pass arguments to home.nix
  #         }
  #       ];
  #     };
  #   };
  # };
}
