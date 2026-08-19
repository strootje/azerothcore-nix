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

  mkAzerothCore = pkgs.callPackage ../pkgs/acore.nix { };

  acorePkg = mkAzerothCore {
    modules = {
      mod-individual-progression = lib.optionalAttrs cfg.modules.individual-progression.enable (
        pkgs.callPackage ../pkgs/modules/individual-progression.nix { }
      );
    };
  };
in
{
  options.services.azerothcore = {
    enable = lib.mkEnableOption "AzerothCore";

    package = lib.mkOption {
      type = lib.types.package;
      default = acorePkg;
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

  options.services.azerothcore.clientData = {
    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.client-data;
    };
  };

  options.services.azerothcore.modules.playerBots = {
    enable = lib.mkEnableOption "AzerothCore modPlayerBots";
  };

  options.services.azerothcore.modules.individual-progression = {
    enable = lib.mkEnableOption "AzerothCore modIndividualProgression";
  };

  config = lib.mkIf cfg.enable {
    users.groups.acore = { };
    users.users.acore = {
      isSystemUser = true;
      group = "acore";
      home = "/var/lib/azerothcore";
    };

    systemd.tmpfiles.rules = [
      "L+ /var/lib/azerothcore/data - - - - ${cfg.clientData.package}"
    ];

    environment.etc."azerothcore/dbimport.conf".text = renderConf "dbimport" {
      LoginDatabaseInfo = "${cfg.database.host};${toString cfg.database.port};${cfg.database.user};${databasePasswd};${cfg.database.authDatabase}";
      WorldDatabaseInfo = "${cfg.database.host};${toString cfg.database.port};${cfg.database.user};${databasePasswd};${cfg.database.worldDatabase}";
      CharacterDatabaseInfo = "${cfg.database.host};${toString cfg.database.port};${cfg.database.user};${databasePasswd};${cfg.database.characterDatabase}";

      MySQLExecutable = "${pkgs.mysql84}/bin/mysql";
      SourceDirectory = "${cfg.package}/src";
      TempDir = "/var/cache/azerothcore";
      LogsDir = "/var/logs/azerothcore";
    };

    environment.etc."azerothcore/authserver.conf".text = renderConf "authserver" {
      LoginDatabaseInfo = "${cfg.database.host};${toString cfg.database.port};${cfg.database.user};${databasePasswd};${cfg.database.authDatabase}";
      "Network.UseSocketActivation" = 1;
      "Updates.EnableDatabases" = 0;

      MySQLExecutable = "${pkgs.mysql84}/bin/mysql";
      SourceDirectory = "${cfg.package}/src";
      TempDir = "/var/cache/azerothcore";
      LogsDir = "/var/logs/azerothcore";
    };

    environment.etc."azerothcore/worldserver.conf".text = renderConf "worldserver" {
      LoginDatabaseInfo = "${cfg.database.host};${toString cfg.database.port};${cfg.database.user};${databasePasswd};${cfg.database.authDatabase}";
      WorldDatabaseInfo = "${cfg.database.host};${toString cfg.database.port};${cfg.database.user};${databasePasswd};${cfg.database.worldDatabase}";
      CharacterDatabaseInfo = "${cfg.database.host};${toString cfg.database.port};${cfg.database.user};${databasePasswd};${cfg.database.characterDatabase}";
      "Network.UseSocketActivation" = 1;
      "Updates.EnableDatabases" = 0;

      MySQLExecutable = "${pkgs.mysql84}/bin/mysql";
      SourceDirectory = "${cfg.package}/src";
      DataDir = "/var/lib/azerothcore/data";
      TempDir = "/var/cache/azerothcore";
      LogsDir = "/var/logs/azerothcore";

      RealmID = 1;
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

    networking.firewall = {
      allowedTCPPorts = [
        3724 # authserver
        8085 # worldserver
      ];
    };

    systemd.services.ac-fix-dbuser = {
      description = "AzerothCore DbUser";

      wantedBy = [
        "multi-user.target"
      ];

      requires = [
        "mysql.service"
      ];
      after = [
        "mysql.service"
      ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;

        Restart = "on-failure";
        RestartSec = 5;
      };

      script = ''
        ${pkgs.mysql84}/bin/mysql <<EOF
          ALTER USER '${cfg.database.user}'@'localhost' IDENTIFIED WITH caching_sha2_password BY '${databasePasswd}';
          FLUSH PRIVILEGES;
        EOF
      '';
    };

    systemd.services.ac-dbimport = {
      description = "AzerothCore DbImport";

      wantedBy = [
        "multi-user.target"
      ];

      requires = [
        "mysql.service"
        "ac-fix-dbuser.service"
      ];
      after = [
        "mysql.service"
        "ac-fix-dbuser.service"
      ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;

        User = "acore";
        Group = "acore";

        StateDirectory = "azerothcore";
        WorkingDirectory = "/var/lib/azerothcore";
        ExecStart = "${cfg.package}/bin/dbimport -c /etc/azerothcore/dbimport.conf";

        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    systemd.sockets.ac-authserver = {
      wantedBy = [
        "sockets.target"
      ];

      partOf = [
        "ac-authserver.service"
      ];

      listenStreams = [ 3724 ];
    };

    systemd.services.ac-authserver = {
      description = "AzerothCore AuthServer";

      requires = [
        "mysql.service"
        "ac-fix-dbuser.service"
        "ac-dbimport.service"
      ];
      after = [
        "mysql.service"
        "ac-fix-dbuser.service"
        "ac-dbimport.service"
      ];

      serviceConfig = {
        Type = "simple";

        User = "acore";
        Group = "acore";

        StateDirectory = "azerothcore";
        WorkingDirectory = "/var/lib/azerothcore";
        ExecStart = "${cfg.package}/bin/authserver -c /etc/azerothcore/authserver.conf";

        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    systemd.sockets.ac-worldserver = {
      wantedBy = [
        "sockets.target"
      ];

      partOf = [
        "ac-worldserver.service"
      ];

      listenStreams = [ 8085 ];
    };

    systemd.services.ac-worldserver = {
      description = "AzerothCore WorldServer";

      requires = [
        "mysql.service"
        "ac-fix-dbuser.service"
        "ac-dbimport.service"
      ];
      after = [
        "mysql.service"
        "ac-fix-dbuser.service"
        "ac-dbimport.service"
      ];

      serviceConfig = {
        Type = "simple";

        User = "acore";
        Group = "acore";

        StateDirectory = "azerothcore";
        WorkingDirectory = "/var/lib/azerothcore";
        ExecStart = "${cfg.package}/bin/worldserver -c /etc/azerothcore/worldserver.conf";

        Restart = "on-failure";
        RestartSec = 5;
      };
    };
  };
}
