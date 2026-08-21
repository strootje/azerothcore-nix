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
    modules = (
      { }

      // (lib.optionalAttrs cfg.modules.ah-bot-plus.enable {
        mod-ah-bot-plus = (pkgs.callPackage ../pkgs/modules/ah-bot-plus.nix { });
      })

      // (lib.optionalAttrs cfg.modules.aoe-loot.enable {
        mod-aoe-loot = (pkgs.callPackage ../pkgs/modules/aoe-loot.nix { });
      })

      // (lib.optionalAttrs cfg.modules.dungeon-clear.enable {
        mod-dungeon-clear = (pkgs.callPackage ../pkgs/modules/dungeon-clear.nix { });
      })

      // (lib.optionalAttrs cfg.modules.individual-progression.enable {
        mod-individual-progression = (pkgs.callPackage ../pkgs/modules/individual-progression.nix { });
      })

      // (lib.optionalAttrs cfg.modules.ollama-chat.enable {
        mod-ollama-chat = (pkgs.callPackage ../pkgs/modules/ollama-chat.nix { });
      })

      // (lib.optionalAttrs cfg.modules.playerbots.enable {
        mod-playerbots = (pkgs.callPackage ../pkgs/modules/playerbots.nix { });
      })
    );
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

  options.services.azerothcore.modules.ah-bot-plus = {
    enable = lib.mkEnableOption "AzerothCore modAhBotPlus";

    settings = {
      sellerGuid = lib.mkOption {
        type = lib.types.str;
        default = "0";
      };
    };
  };

  options.services.azerothcore.modules.aoe-loot = {
    enable = lib.mkEnableOption "AzerothCore modAoeLoot";

    settings = {
      range = lib.mkOption {
        type = lib.types.int;
        default = 55;
      };
    };
  };

  options.services.azerothcore.modules.dungeon-clear = {
    enable = lib.mkEnableOption "AzerothCore modDungeonClear";

    settings = {
      pullMode = lib.mkOption {
        type = lib.types.int;
        # 0=off, 1=on, 2=dynamic — bump to 2 once you trust it
        default = 1;
      };
    };
  };

  options.services.azerothcore.modules.individual-progression = {
    enable = lib.mkEnableOption "AzerothCore modIndividualProgression";
  };

  options.services.azerothcore.modules.ollama-chat = {
    enable = lib.mkEnableOption "AzerothCore modOllamaChat";
  };

  options.services.azerothcore.modules.playerbots = {
    enable = lib.mkEnableOption "AzerothCore modPlayerbots";

    databaseName = lib.mkOption {
      type = lib.types.str;
      default = "acore_playerbots";
    };

    settings = {
      minRandomBots = lib.mkOption {
        type = lib.types.int;
        default = 250;
      };
      maxRandomBots = lib.mkOption {
        type = lib.types.int;
        default = 500;
      };
    };
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
      "d /var/cache/azerothcore 0750 acore acore -"
      "d /var/log/azerothcore 0750 acore acore -"
    ];

    environment.etc."azerothcore/dbimport.conf".text = renderConf "dbimport" (
      {
        LoginDatabaseInfo = "${cfg.database.host};${toString cfg.database.port};${cfg.database.user};${databasePasswd};${cfg.database.authDatabase}";
        WorldDatabaseInfo = "${cfg.database.host};${toString cfg.database.port};${cfg.database.user};${databasePasswd};${cfg.database.worldDatabase}";
        CharacterDatabaseInfo = "${cfg.database.host};${toString cfg.database.port};${cfg.database.user};${databasePasswd};${cfg.database.characterDatabase}";

        MySQLExecutable = "${pkgs.mysql84}/bin/mysql";
        SourceDirectory = "${cfg.package}/sql-files";
        TempDir = "/var/cache/azerothcore";
        LogsDir = "/var/log/azerothcore";
      }
      // (lib.optionalAttrs cfg.modules.playerbots.enable {
        PlayerbotsDatabaseInfo = "${cfg.database.host};${toString cfg.database.port};${cfg.database.user};${databasePasswd};${cfg.modules.playerbots.databaseName}";
        "Playerbots.Updates.EnableDatabases" = 1;
      })
    );

    environment.etc."azerothcore/authserver.conf".text = renderConf "authserver" {
      BindIP = "0.0.0.0";
      LoginDatabaseInfo = "${cfg.database.host};${toString cfg.database.port};${cfg.database.user};${databasePasswd};${cfg.database.authDatabase}";
      # "Network.UseSocketActivation" = 1;
      "Updates.EnableDatabases" = 0;

      MySQLExecutable = "${pkgs.mysql84}/bin/mysql";
      SourceDirectory = "${cfg.package}/sql-files";
      TempDir = "/var/cache/azerothcore";
      LogsDir = "/var/log/azerothcore";
    };

    environment.etc."azerothcore/worldserver.conf".text = renderConf "worldserver" (
      {
        BindIP = "0.0.0.0";
        LoginDatabaseInfo = "${cfg.database.host};${toString cfg.database.port};${cfg.database.user};${databasePasswd};${cfg.database.authDatabase}";
        WorldDatabaseInfo = "${cfg.database.host};${toString cfg.database.port};${cfg.database.user};${databasePasswd};${cfg.database.worldDatabase}";
        CharacterDatabaseInfo = "${cfg.database.host};${toString cfg.database.port};${cfg.database.user};${databasePasswd};${cfg.database.characterDatabase}";
        # "Network.UseSocketActivation" = 1;
        "Updates.EnableDatabases" = 0;

        MySQLExecutable = "${pkgs.mysql84}/bin/mysql";
        SourceDirectory = "${cfg.package}/sql-files";
        DataDir = "/var/lib/azerothcore/data";
        TempDir = "/var/cache/azerothcore";
        LogsDir = "/var/log/azerothcore";

        RealmID = 1;
        "Stats.Limits.Enable" = 0;
        "Console.Enable" = 0;
      }
      // (lib.optionalAttrs cfg.modules.ah-bot-plus.enable {
        "AuctionHouseBot.EnableSeller" = true;
        "AuctionHouseBot.GUIDs" = cfg.modules.ah-bot-plus.settings.sellerGuid;
        "AuctionHouseBot.Alliance.MinItems" = 200;
        "AuctionHouseBot.Alliance.MaxItems" = 400;
        "AuctionHouseBot.Horde.MinItems" = 200;
        "AuctionHouseBot.Horde.MaxItems" = 400;
        "AuctionHouseBot.Neutral.MinItems" = 200;
        "AuctionHouseBot.Neutral.MaxItems" = 400;
        "AuctionHouseBot.Buyer.Enabled" = false;
      })
      // (lib.optionalAttrs cfg.modules.aoe-loot.enable {
        "AOELoot.Message" = 0;
        "AOELoot.Enable" = 1;
        "AOELoot.Range" = cfg.modules.aoe-loot.settings.range;
      })
      // (lib.optionalAttrs cfg.modules.dungeon-clear.enable {
        "DungeonClear.PullMode" = cfg.modules.dungeon-clear.settings.pullMode;
      })
      // (lib.optionalAttrs cfg.modules.playerbots.enable {
        PlayerbotsDatabaseInfo = "${cfg.database.host};${toString cfg.database.port};${cfg.database.user};${databasePasswd};${cfg.modules.playerbots.databaseName}";
        "Playerbots.Updates.EnableDatabases" = 1;
        "AiPlayerbot.DisabledWithoutRealPlayer" = 1;
        "AiPlayerbot.MinRandomBots" = cfg.modules.playerbots.settings.minRandomBots;
        "AiPlayerbot.MaxRandomBots" = cfg.modules.playerbots.settings.maxRandomBots;
        "AiPlayerbot.RandomBotAutologinDelay" = 30;
      })
    );

    services.mysql = lib.mkIf cfg.database.managed {
      package = pkgs.mysql84;
      enable = true;

      ensureDatabases = (
        [
          cfg.database.authDatabase
          cfg.database.worldDatabase
          cfg.database.characterDatabase
        ]
        ++ (lib.optionals cfg.modules.playerbots.enable [ cfg.modules.playerbots.databaseName ])
      );

      ensureUsers = [
        {
          name = cfg.database.user;
          ensurePermissions = (
            {
              "${cfg.database.authDatabase}.*" = "ALL PRIVILEGES";
              "${cfg.database.worldDatabase}.*" = "ALL PRIVILEGES";
              "${cfg.database.characterDatabase}.*" = "ALL PRIVILEGES";
            }
            // (lib.optionalAttrs cfg.modules.playerbots.enable {
              "${cfg.modules.playerbots.databaseName}.*" = "ALL PRIVILEGES";
            })
          );
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

      restartTriggers = [
        "/etc/azerothcore/dbimport.conf"
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

    # systemd.sockets.ac-authserver = {
    #   wantedBy = [
    #     "sockets.target"
    #   ];

    #   partOf = [
    #     "ac-authserver.service"
    #   ];

    #   listenStreams = [ 3724 ];
    # };

    systemd.services.ac-authserver = {
      description = "AzerothCore AuthServer";

      wantedBy = [
        "multi-user.target"
      ];

      restartTriggers = [
        "/etc/azerothcore/authserver.conf"
      ];

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

      wants = [
        "ac-worldserver.service"
      ];
      before = [
        "ac-worldserver.service"
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

    # systemd.sockets.ac-worldserver = {
    #   wantedBy = [
    #     "sockets.target"
    #   ];

    #   partOf = [
    #     "ac-worldserver.service"
    #   ];

    #   listenStreams = [ 8085 ];
    # };

    systemd.services.ac-worldserver = {
      description = "AzerothCore WorldServer";

      wantedBy = [
        "multi-user.target"
      ];

      restartTriggers = [
        "/etc/azerothcore/worldserver.conf"
      ];

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
