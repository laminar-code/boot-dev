{
  inputs = {
    nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";
    devenv.url = "github:cachix/devenv";
  };

  outputs = { self, nixpkgs, devenv, ... }@inputs:
  let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in
  {
    packages.${system} = {
      projectA-devenv-up = self.devShells.${system}.projectA.config.procfileScript;
      projectA-devenv-test = self.devShells.${system}.projectA.config.test;

      projectB-devenv-up = self.devShells.${system}.projectB.config.procfileScript;
      projectB-devenv-test = self.devShells.${system}.projectB.config.test;
    };

    devShells.${system} = {
      projectA = devenv.lib.mkShell {
        inherit inputs pkgs;
        modules = [
          {
            enterShell = ''
              echo this is project A
            '';
          }
        ];
      };

      projectB = devenv.lib.mkShell {
        inherit inputs pkgs;
        modules = [
          {
            enterShell = ''
              echo this is project B
            '';
          }
        ];
      };
    };
  };
}

