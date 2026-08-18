{ self }:
{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.services.azerothcore;
in
{
  options.services.azerothcore = {
    enable = lib.mkEnableOption "AzerothCore";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.system}.acore;
    };
  };

  options.services.azerothcore.database = {
    managed = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "localhost";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3306;
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "acore";
    };

    # passwordFile = lib.mkOption {
    #   type = lib.types.path;
    # };

    authDatabase = lib.mkOption {
      type = lib.types.str;
      default = "acore_auth";
    };

    worldDatabase = lib.mkOption {
      type = lib.types.str;
      default = "acore_world";
    };

    characterDatabase = lib.mkOption {
      type = lib.types.str;
      default = "acore_characters";
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.acore = { };
    users.users.acore = {
      isSystemUser = true;
      group = "acore";
      home = "/var/lib/azerothcore";
    };

    environment.etc."azerothcore/authserver.conf".source = "${cfg.package}/etc/authserver.conf.dist";
    environment.etc."azerothcore/worldserver.conf".source = "${cfg.package}/etc/worldserver.conf.dist";

    services.mysql = lib.mkIf cfg.database.managed {
      package = pkgs.mariadb;
      enable = true;

      ensureDatabases = [
        cfg.database.authDatabase
        cfg.database.worldDatabase
        cfg.database.characterDatabase
      ];

      ensureUsers = [
        {
          name = cfg.database.user;
          ensurePermissions = {
            "${cfg.database.authDatabase}.*" = "ALL PRIVILEGES";
            "${cfg.database.worldDatabase}.*" = "ALL PRIVILEGES";
            "${cfg.database.characterDatabase}.*" = "ALL PRIVILEGES";
          };
        }
      ];
    };

    systemd.services.auhtserver = {
      description = "AzerothCore AuthServer";
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        User = "acore";
        Group = "acore";

        StateDirectory = "azerothcore";
        WorkingDirectory = "/var/lib/azerothcore";

        ExecStart = "${cfg.package}/bin/authserver";
        Restart = "always";
      };
    };

    systemd.services.worldserver = {
      description = "AzerothCore WorldServer";
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        User = "acore";
        Group = "acore";

        StateDirectory = "azerothcore";
        WorkingDirectory = "/var/lib/azerothcore";

        ExecStart = "${cfg.package}/bin/worldserver";
        Restart = "always";
      };
    };
  };
}
