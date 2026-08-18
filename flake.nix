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
        packages = rec {
          acore = pkgs.callPackage pkgs/acore.nix { };
          default = acore;
        };
      };

      flake.nixosModules.default = import nixos/module.nix {
        inherit self;
      };
    };
}
