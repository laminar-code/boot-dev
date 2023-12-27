{
  description = "A Basic Flake (Template)";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-23.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }: 
    flake-utils.lib.eachDefaultSystem(system: 
      let pkgs = import nixpkgs { inherit system; };
      in {
        packages = {
          hello = nixpkgs.legacyPackages.x86_64-linux.hello;
          default = self.packages.x86_64-linux.hello;
        };
      }
    );
}
