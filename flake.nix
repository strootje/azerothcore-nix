{
  inputs = {
    nixpkgs = {
      url = "github:nixos/nixpkgs/nixos-unstable";
    };

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
    };
  };

  outputs =
    inputs@{ self, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];

      perSystem = { pkgs, ... }: {
        packages =
          let
            mkAzerothCore = pkgs.callPackage pkgs/acore.nix { };
          in
          {
            acore = mkAzerothCore { };

            acore-playerbots = mkAzerothCore {
              modules = {
                mod-playerbots = pkgs.callPackage pkgs/modules/playerbots.nix { };
              };
            };

            client-data = pkgs.callPackage pkgs/client-data.nix { };
          };
      };

      flake.nixosModules.default = import nixos/module.nix {
        inherit self;
      };
    };
}
