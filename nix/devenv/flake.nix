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
      java-devenv-up = self.devShells.${system}.java.config.procfileScript;
      java-devenv-test = self.devShells.${system}.java.config.test;

      python-devenv-up = self.devShells.${system}.python.config.procfileScript;
      python-devenv-test = self.devShells.${system}.python.config.test;
      
      node-devenv-up = self.devShells.${system}.node.config.procfileScript;
      node-devenv-test = self.devShells.${system}.node.config.test;
    };

    devShells.${system} = {
      java = devenv.lib.mkShell {
        inherit inputs pkgs;
        modules = [
          ({ pkgs, config, ... }: {
            packages = with pkgs; [ 
              zulu
            ];
            enterShell = ''
              echo Java shell...
            '';
          })
        ];
      };

      python = devenv.lib.mkShell {
        inherit inputs pkgs;
        modules = [
          {
            enterShell = ''
              echo Python shell...
            '';
          }
        ];
      };

      node = devenv.lib.mkShell {
        inherit inputs pkgs;
        modules = [
          {
            enterShell = ''
              echo Node shell...
            '';
          }
        ];
      };
    };
  };
}

