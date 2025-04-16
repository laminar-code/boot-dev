{
  inputs = {
    nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";
    devenv.url = "github:cachix/devenv";
  };

  outputs = { self, nixpkgs, devenv, ... }@inputs:
  let
    # system = "x86_64-linux";
    # The following line requires --no-pure-eval to work
    system = builtins.currentSystem;
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
              # language packages
              zulu
              clojure
              babashka

              # database drivers
              postgresql_jdbc
              sqlite-jdbc
              oracle-instantclient
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
              gcc
              stdenv.cc.cc
              (python3.withPackages (ps: with ps; [
                pip
                setuptools
                virtualenv
              ]))
            ];
            enterShell = ''
              echo Python shell...
              export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath [
                pkgs.stdenv.cc.cc
              ]}
              virtualenv --quiet pylocal
              pip install --quiet --upgrade pip
              source ./venv/bin/activate > /dev/null
            '';
          })
        ];
      };

      keeper = devenv.lib.mkShell {
        inherit inputs pkgs;
        modules = [
          ({ pkgs, config, ... }: {
            packages = with pkgs; [ 
              gcc
              stdenv.cc.cc
              (python3.withPackages (ps: with ps; [
                pip
                setuptools
                virtualenv
              ]))
            ];
            enterShell = ''
              echo Keeper shell...
              export LD_LIBRARY_PATH=${pkgs.lib.makeLibraryPath [
                pkgs.stdenv.cc.cc
              ]}
              virtualenv --quiet pylocal
              source ./pylocal/bin/activate > /dev/null
              pip install --quiet --upgrade pip
              pip3 install --quiet keepercommander
              pip3 install --quiet --upgrade keepercommander
              keeper shell
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

