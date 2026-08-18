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
    + lib.concatLines (lib.mapAttrsToList (name: value: "${name} = \"${toString value}\"") settings);
  databasePasswd = "acore";
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

    environment.etc."azerothcore/authserver.conf".text = renderConf "authserver" {
      LoginDatabaseInfo = "${cfg.database.host};${toString cfg.database.port};${cfg.database.user};${databasePasswd};${cfg.database.authDatabase}";

    };
    environment.etc."azerothcore/worldserver.conf".text = renderConf "worldserver" {
      LoginDatabaseInfo = "${cfg.database.host};${toString cfg.database.port};${cfg.database.user};${databasePasswd};${cfg.database.authDatabase}";
      WorldDatabaseInfo = "${cfg.database.host};${toString cfg.database.port};${cfg.database.user};${databasePasswd};${cfg.database.worldDatabase}";
      CharacterDatabaseInfo = "${cfg.database.host};${toString cfg.database.port};${cfg.database.user};${databasePasswd};${cfg.database.characterDatabase}";
    };
    environment.etc."azerothcore/dbimport.conf".text = renderConf "dbimport" {
      LoginDatabaseInfo = "${cfg.database.host};${toString cfg.database.port};${cfg.database.user};${databasePasswd};${cfg.database.authDatabase}";
      WorldDatabaseInfo = "${cfg.database.host};${toString cfg.database.port};${cfg.database.user};${databasePasswd};${cfg.database.worldDatabase}";
      CharacterDatabaseInfo = "${cfg.database.host};${toString cfg.database.port};${cfg.database.user};${databasePasswd};${cfg.database.characterDatabase}";
      MySQLExecutable = "${pkgs.mysql84}/bin/mysql";
      SourceDirectory = "${cfg.package}/data";
    };

    services.mysql = lib.mkIf cfg.database.managed {
      package = pkgs.mysql84;
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

    # systemd.services.ac-update-user = {
    #   serviceConfig.Type = "oneshot";
    #   wantedBy = [ "multi-user.target" ];
    #   requires = [ "mysql.service" ];
    #   after = [ "mysql.service" ];

    #   script = ''
    #     ${pkgs.mysql84}/bin/mysql <<EOF
    #       ALTER USER '${cfg.database.user}'@'localhost' IDENTIFIED BY '${databasePasswd}';
    #       FLUSH PRIVILEGES;
    #     EOF
    #   '';
    # };

    systemd.services.ac-db-import = {
      description = "AzerothCore DbImport";

      wantedBy = [ "multi-user.target" ];
      requires = [ "mysql.service" ];
      after = [ "mysql.service" ];

      before = [
        "ac-authserver.service"
        "ac-worldserver.service"
      ];

      serviceConfig = {
        Type = "oneshot";

        User = "acore";
        Group = "acore";

        StateDirectory = "azerothcore";
        WorkingDirectory = "/var/lib/azerothcore";

        # ExecStartPre = "${cfg.package}/bin/authserver -c /etc/azerothcore/authserver.conf -d";
        ExecStart = "${cfg.package}/bin/dbimport -c /etc/azerothcore/dbimport.conf";

        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    systemd.services.ac-authserver = {
      description = "AzerothCore AuthServer";

      wantedBy = [ "multi-user.target" ];
      requires = [ "mysql.service" ];
      after = [ "mysql.service" ];

      serviceConfig = {
        Type = "simple";

        User = "acore";
        Group = "acore";

        StateDirectory = "azerothcore";
        WorkingDirectory = "/var/lib/azerothcore";

        # ExecStartPre = "${cfg.package}/bin/authserver -c /etc/azerothcore/authserver.conf -d";
        ExecStart = "${cfg.package}/bin/authserver -c /etc/azerothcore/authserver.conf";

        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    systemd.services.ac-worldserver = {
      description = "AzerothCore WorldServer";

      wantedBy = [ "multi-user.target" ];
      requires = [ "mysql.service" ];
      after = [ "mysql.service" ];

      serviceConfig = {
        Type = "simple";

        User = "acore";
        Group = "acore";

        StateDirectory = "azerothcore";
        WorkingDirectory = "/var/lib/azerothcore";

        # ExecStartPre = "${cfg.package}/bin/worldserver -c /etc/azerothcore/worldserver.conf -d";
        ExecStart = "${cfg.package}/bin/worldserver -c /etc/azerothcore/worldserver.conf";

        Restart = "on-failure";
        RestartSec = 5;
      };
    };
  };
}
