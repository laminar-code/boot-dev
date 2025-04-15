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
              clojure
              babashka
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
          ({ pkgs, config, ... }: {
            packages = with pkgs; [ 
              (python3.withPackages (ps: with ps; [
                pip
                setuptools
              ]))
            ];
            enterShell = ''
              echo Python shell...
            '';
          })
        ];
      };

      javascript = devenv.lib.mkShell {
        inherit inputs pkgs;
        modules = [
          ({ pkgs, config, ... }: {
            packages = with pkgs; [ 
              bun
              pnpm
            ];
            enterShell = ''
              echo JavaScript shell...
            '';
          })
        ];
      };

      go = devenv.lib.mkShell {
        inherit inputs pkgs;
        modules = [
          ({ pkgs, config, ... }: {
            packages = with pkgs; [ 
              go
            ];
            enterShell = ''
              echo Go shell...
            '';
          })
        ];
      };
    };
  };
}

