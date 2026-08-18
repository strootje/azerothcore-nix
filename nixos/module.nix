{ self }:
{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.services.azerothcore;

  renderConf =
    section: settings:
    ''
      [${section}]
    ''
    ++ lib.concatLines (lib.mapAttrsToList (name: value: "${name} = \"${toString value}\"") settings);
in
{
  options.services.azerothcore = {
    enable = lib.mkEnableOption "AzerothCore";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.acore;
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

    environment.etc."azerothcore/authserver.conf".text = ''
      [authserver]
      LoginDatabaseInfo = "${cfg.database.host};${cfg.database.port};${cfg.database.user};;${cfg.database.authDatabase}"
    '';
    environment.etc."azerothcore/worldserver.conf".text = ''
      [worldserver]
      LoginDatabaseInfo = "${cfg.database.host};${cfg.database.port};${cfg.database.user};;${cfg.database.authDatabase}"
      WorldDatabaseInfo = "${cfg.database.host};${cfg.database.port};${cfg.database.user};;${cfg.database.worldDatabase}"
      CharacterDatabaseInfo = "${cfg.database.host};${cfg.database.port};${cfg.database.user};;${cfg.database.characterDatabase}"
    '';

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

        ExecStartPre = "${cfg.package}/bin/authserver -c /etc/azerothcore/authserver.conf -d";
        ExecStart = "${cfg.package}/bin/authserver -c /etc/azerothcore/authserver.conf";
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

        ExecStartPre = "${cfg.package}/bin/worldserver -c /etc/azerothcore/worldserver.conf -d";
        ExecStart = "${cfg.package}/bin/worldserver -c /etc/azerothcore/worldserver.conf";
        Restart = "always";
      };
    };
  };
}
