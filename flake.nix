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

            acore-full = mkAzerothCore {
              modules = {
                mod-ah-bot-plus = pkgs.callPackage pkgs/modules/ah-bot-plus.nix { };
                mod-aoe-loot = pkgs.callPackage pkgs/modules/aoe-loot.nix { };
                mod-dungeon-clear = pkgs.callPackage pkgs/modules/dungeon-clear.nix { };
                mod-individual-progression = pkgs.callPackage pkgs/modules/individual-progression.nix { };
                mod-ollama-chat = pkgs.callPackage pkgs/modules/ollama-chat.nix { };
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
