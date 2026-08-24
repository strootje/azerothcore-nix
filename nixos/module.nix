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
        mod-levelsync = (pkgs.callPackage ../pkgs/modules/levelsync.nix { });
      })

      // (lib.optionalAttrs cfg.modules.ollama-chat.enable {
        mod-ollama-chat = (pkgs.callPackage ../pkgs/modules/ollama-chat.nix { });
      })

      // (lib.optionalAttrs cfg.modules.playerbots.enable {
        mod-multibot-bridge = (pkgs.callPackage ../pkgs/modules/multibot-bridge.nix { });
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
        "LoginDatabaseInfo" =
          "${cfg.database.host};${toString cfg.database.port};${cfg.database.user};${databasePasswd};${cfg.database.authDatabase}";
        "WorldDatabaseInfo" =
          "${cfg.database.host};${toString cfg.database.port};${cfg.database.user};${databasePasswd};${cfg.database.worldDatabase}";
        "CharacterDatabaseInfo" =
          "${cfg.database.host};${toString cfg.database.port};${cfg.database.user};${databasePasswd};${cfg.database.characterDatabase}";

        "Updates.AutoSetup" = 1;
        "Updates.AllowedModules" = "all";
        "Updates.EnableDatabases" = 15;
        "Updates.Redundancy" = 1;
        "Updates.ArchivedRedundancy" = 0;
        "Updates.AllowRehash" = 1;
        "Updates.CleanDeadRefMaxCount" = 3;

        "MySQLExecutable" = "${pkgs.mysql84}/bin/mysql";
        "SourceDirectory" = "${cfg.package}/sql-files";
        "TempDir" = "/var/cache/azerothcore";
        "LogsDir" = "/var/log/azerothcore";
      }
      // (lib.optionalAttrs cfg.modules.playerbots.enable {
        "PlayerbotsDatabaseInfo" =
          "${cfg.database.host};${toString cfg.database.port};${cfg.database.user};${databasePasswd};${cfg.modules.playerbots.databaseName}";
        "Playerbots.Updates.EnableDatabases" = 1;
      })
    );

    environment.etc."azerothcore/authserver.conf".text = renderConf "authserver" {
      "BindIP" = "0.0.0.0";
      "LoginDatabaseInfo" =
        "${cfg.database.host};${toString cfg.database.port};${cfg.database.user};${databasePasswd};${cfg.database.authDatabase}";
      # "Network.UseSocketActivation" = 1;
      "Updates.EnableDatabases" = 0;

      "MySQLExecutable" = "${pkgs.mysql84}/bin/mysql";
      "SourceDirectory" = "${cfg.package}/sql-files";
      "TempDir" = "/var/cache/azerothcore";
      "LogsDir" = "/var/log/azerothcore";
    };

    environment.etc."azerothcore/worldserver.conf".text = renderConf "worldserver" (
      {
        "BindIP" = "0.0.0.0";
        "LoginDatabaseInfo" =
          "${cfg.database.host};${toString cfg.database.port};${cfg.database.user};${databasePasswd};${cfg.database.authDatabase}";
        "WorldDatabaseInfo" =
          "${cfg.database.host};${toString cfg.database.port};${cfg.database.user};${databasePasswd};${cfg.database.worldDatabase}";
        "CharacterDatabaseInfo" =
          "${cfg.database.host};${toString cfg.database.port};${cfg.database.user};${databasePasswd};${cfg.database.characterDatabase}";
        # "Network.UseSocketActivation" = 1;
        "Updates.EnableDatabases" = 0;

        "MySQLExecutable" = "${pkgs.mysql84}/bin/mysql";
        "SourceDirectory" = "${cfg.package}/sql-files";
        "DataDir" = "/var/lib/azerothcore/data";
        "TempDir" = "/var/cache/azerothcore";
        "LogsDir" = "/var/log/azerothcore";

        "RealmID" = 1;
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
      // (lib.optionalAttrs cfg.modules.individual-progression.enable {
        "IndividualProgression.Enable" = 1;
        "IndividualProgression.VanillaPowerAdjustment" = 0.5;
        "IndividualProgression.VanillaHealingAdjustment" = 0.5;
        "IndividualProgression.TBCPowerAdjustment" = 0.5;
        "IndividualProgression.TBCHealingAdjustment" = 0.5;
        "IndividualProgression.RequireNaxxStrathEntrance" = 1;
        "DBC.EnforceItemAttributes" = 0;
        "EnablePlayerSettings" = 1;
      })
      // (lib.optionalAttrs cfg.modules.playerbots.enable {
        "PlayerbotsDatabaseInfo" =
          "${cfg.database.host};${toString cfg.database.port};${cfg.database.user};${databasePasswd};${cfg.modules.playerbots.databaseName}";
        "Playerbots.Updates.EnableDatabases" = 1;
        "AiPlayerbot.DisabledWithoutRealPlayer" = 1;
        "AiPlayerbot.MinRandomBots" = cfg.modules.playerbots.settings.minRandomBots;
        "AiPlayerbot.MaxRandomBots" = cfg.modules.playerbots.settings.maxRandomBots;
        "AiPlayerbot.RandomBotAutologinDelay" = 30;

        ###################################
        #                                 #
        # PREMADE SPECS                   #
        #                                 #
        ###################################

        ####################################################################################################
        # INFORMATION
        #

        "# AiPlayerbot.PremadeSpecName.<class>.<specno>" =
          "<name>         #Name of the talent specialisation";
        "# AiPlayerbot.PremadeSpecLink.<class>.<specno>.<level>" =
          "<link> #Wowhead style link the bot should work towards at given level.";
        "# AiPlayerbot.PremadeSpecGlyph.<class>.<specno>" =
          "<major 1>,<minor 1>,<major 2>,<minor 2>,<minor 3>,<major 3>   #ItemId of the glyphs";
        # e.g., formulate the link on https://www.wowhead.com/wotlk/talent-calc/warrior/3022032123335100202012013031251-32505010002
        # 0 <= specno < 20, 1 <= level <= 80

        #
        #
        ####################################################################################################

        ####################################################################################################
        # WARRIOR
        #

        "AiPlayerbot.PremadeSpecName.1.0" = "arms pve";
        "AiPlayerbot.PremadeSpecGlyph.1.0" = "43418,43395,43423,43399,43397,43421";
        "AiPlayerbot.PremadeSpecLink.1.0.60" = "3022032023335100002012211231241";
        "AiPlayerbot.PremadeSpecLink.1.0.80" = "3022032023335100102012213231251-305-2033";
        "AiPlayerbot.PremadeSpecName.1.1" = "fury pve";
        "AiPlayerbot.PremadeSpecGlyph.1.1" = "43418,43395,43414,43396,49084,43432";
        "AiPlayerbot.PremadeSpecLink.1.1.60" = "-305053000500310053120501351";
        "AiPlayerbot.PremadeSpecLink.1.1.80" = "32002300233-305053000500310153120511351";
        "AiPlayerbot.PremadeSpecName.1.2" = "prot pve";
        "AiPlayerbot.PremadeSpecGlyph.1.2" = "43429,43397,43425,43399,49084,45797";
        "AiPlayerbot.PremadeSpecLink.1.2.60" = "--053351225000210521030113321";
        "AiPlayerbot.PremadeSpecLink.1.2.80" = "3500030023-301-053351225000210521030113321";
        "AiPlayerbot.PremadeSpecName.1.3" = "arms pvp";
        "AiPlayerbot.PremadeSpecGlyph.1.3" = "43417,43397,43423,43396,49084,43421";
        "AiPlayerbot.PremadeSpecLink.1.3.60" = "0320232023331100032212012221251";
        "AiPlayerbot.PremadeSpecLink.1.3.80" = "0320332023335100232212013231251-3250001";
        "AiPlayerbot.PremadeSpecName.1.4" = "fury pvp";
        "AiPlayerbot.PremadeSpecGlyph.1.4" = "43432,43397,43417,43395,43396,43418";
        "AiPlayerbot.PremadeSpecLink.1.4.60" = "-325000131500212250120511351";
        "AiPlayerbot.PremadeSpecLink.1.4.80" = "03220300233-325000131500212250122511351";
        "AiPlayerbot.PremadeSpecName.1.5" = "prot pvp";
        "AiPlayerbot.PremadeSpecGlyph.1.5" = "43425,43397,43415,43396,49084,45792";
        "AiPlayerbot.PremadeSpecLink.1.5.60" = "--250031220223012520332113321";
        "AiPlayerbot.PremadeSpecLink.1.5.80" = "0502300123-3-250031220223012521332113321";

        #
        #
        ####################################################################################################

        ####################################################################################################
        # PALADIN
        #

        "AiPlayerbot.PremadeSpecName.2.0" = "holy pve";
        "AiPlayerbot.PremadeSpecGlyph.2.0" = "41106,43367,45741,43368,43365,41109";
        "AiPlayerbot.PremadeSpecLink.2.0.60" = "50350151020013053100515221";
        "AiPlayerbot.PremadeSpecLink.2.0.80" = "50350152100013053100515221-50320104203";
        "AiPlayerbot.PremadeSpecName.2.1" = "prot pve";
        "AiPlayerbot.PremadeSpecGlyph.2.1" = "41100,43367,43869,43368,43369,45745";
        "AiPlayerbot.PremadeSpecLink.2.1.60" = "-05005135203102311333112321";
        "AiPlayerbot.PremadeSpecLink.2.1.80" = "-05005135203102311333312321-502302012003";
        "AiPlayerbot.PremadeSpecName.2.2" = "ret pve";
        "AiPlayerbot.PremadeSpecGlyph.2.2" = "41092,43367,41099,43368,43340,43869";
        "AiPlayerbot.PremadeSpecLink.2.2.60" = "--05230051203331302133231131";
        "AiPlayerbot.PremadeSpecLink.2.2.65" = "-05-05230051203331302133231131";
        "AiPlayerbot.PremadeSpecLink.2.2.80" = "050501-05-05232051203331302133231331";
        "AiPlayerbot.PremadeSpecName.2.3" = "holy pvp";
        "AiPlayerbot.PremadeSpecGlyph.2.3" = "41110,43367,45746,43369,43365,45747";
        "AiPlayerbot.PremadeSpecLink.2.3.60" = "50332150300013050133215221";
        "AiPlayerbot.PremadeSpecLink.2.3.80" = "50332150300013050133315221-5032013122";
        "AiPlayerbot.PremadeSpecName.2.4" = "prot pvp";
        "AiPlayerbot.PremadeSpecGlyph.2.4" = "41092,43367,41101,43369,43365,45745";
        "AiPlayerbot.PremadeSpecLink.2.4.60" = "-15320130223122311323311321";
        "AiPlayerbot.PremadeSpecLink.2.4.80" = "-15320130223122321333312321-052300502";
        "AiPlayerbot.PremadeSpecName.2.5" = "ret pvp";
        "AiPlayerbot.PremadeSpecGlyph.2.5" = "41095,43367,41102,43369,43365,45747";
        "AiPlayerbot.PremadeSpecLink.2.5.60" = "--05230250203331222133201321";
        "AiPlayerbot.PremadeSpecLink.2.5.80" = "-1532013022-05230250203331322133201321";

        #
        #
        ####################################################################################################

        ####################################################################################################
        # HUNTER
        #

        "AiPlayerbot.PremadeSpecName.3.0" = "bm pve";
        "AiPlayerbot.PremadeSpecGlyph.3.0" = "42912,43350,42902,43351,43338,42914";
        "AiPlayerbot.PremadeSpecLink.3.0.40" = "512002015051122301";
        "AiPlayerbot.PremadeSpecLink.3.0.60" = "51200201505112233110531151";
        "AiPlayerbot.PremadeSpecLink.3.0.80" = "51200201505112233111531351-0323031-5";
        "AiPlayerbot.PremadeSpecName.3.1" = "mm pve";
        "AiPlayerbot.PremadeSpecGlyph.3.1" = "42912,43350,45625,43351,43338,42914";
        "AiPlayerbot.PremadeSpecLink.3.1.60" = "-035305101030013233115031151";
        "AiPlayerbot.PremadeSpecLink.3.1.80" = "502-035305101230013233135031351-5000002";
        "AiPlayerbot.PremadeSpecName.3.2" = "surv pve";
        "AiPlayerbot.PremadeSpecGlyph.3.2" = "45733,43350,45731,43351,43338,45732";
        "AiPlayerbot.PremadeSpecLink.3.2.60" = "--5000032500033330502135201311";
        "AiPlayerbot.PremadeSpecLink.3.2.80" = "-005305101-5000032500033330532135301321";
        "AiPlayerbot.PremadeSpecName.3.3" = "bm pvp";
        "AiPlayerbot.PremadeSpecGlyph.3.3" = "42897,42900,42902,43356,43338,42900";
        "AiPlayerbot.PremadeSpecLink.3.3.60" = "05203201505012233100531151";
        "AiPlayerbot.PremadeSpecLink.3.3.80" = "05203201505012233100531351-005305101-03";
        "AiPlayerbot.PremadeSpecName.3.4" = "mm pvp";
        "AiPlayerbot.PremadeSpecGlyph.3.4" = "42912,43351,42897,43338,43356,42904";
        "AiPlayerbot.PremadeSpecLink.3.4.60" = "-034305101030213231135031051";
        "AiPlayerbot.PremadeSpecLink.3.4.80" = "-035305101030213233135031051-53013020102";
        "AiPlayerbot.PremadeSpecName.3.5" = "surv pvp";
        "AiPlayerbot.PremadeSpecGlyph.3.5" = "42912,43350,42904,43356,43338,45731";
        "AiPlayerbot.PremadeSpecLink.3.5.60" = "--2300302410233030533135001031";
        "AiPlayerbot.PremadeSpecLink.3.5.80" = "-005305201-2300302510233330533135001031";

        # HUNTER PET
        #
        # Ferocity
        "AiPlayerbot.PremadeHunterPetLink.0.16" = "2100003130003010101";
        "AiPlayerbot.PremadeHunterPetLink.0.20" = "2100003130103010122";
        # Tenacity
        "AiPlayerbot.PremadeHunterPetLink.1.16" = "21103000300120101001";
        "AiPlayerbot.PremadeHunterPetLink.1.20" = "21303010300120101002";
        # Cunning
        "AiPlayerbot.PremadeHunterPetLink.2.16" = "2100020330000211001";
        "AiPlayerbot.PremadeHunterPetLink.2.20" = "21000203300002110221";

        #
        #
        ####################################################################################################

        ####################################################################################################
        # ROGUE
        #

        "AiPlayerbot.PremadeSpecName.4.0" = "as pve";
        "AiPlayerbot.PremadeSpecGlyph.4.0" = "45768,43379,45761,43380,43378,45766";
        "AiPlayerbot.PremadeSpecLink.4.0.60" = "005303104352100520103331051";
        "AiPlayerbot.PremadeSpecLink.4.0.80" = "005303005352100520103331051-005005003-502";
        "AiPlayerbot.PremadeSpecName.4.1" = "combat pve";
        "AiPlayerbot.PremadeSpecGlyph.4.1" = "42962,43379,45762,43380,43378,42969";
        "AiPlayerbot.PremadeSpecLink.4.1.60" = "-0252051000035015223100501251";
        "AiPlayerbot.PremadeSpecLink.4.1.80" = "00532000523-0252051000035015223100501251";
        "AiPlayerbot.PremadeSpecName.4.2" = "subtlety pve";
        "AiPlayerbot.PremadeSpecGlyph.4.2" = "42967,43379,45764,43380,43378,45767";
        "AiPlayerbot.PremadeSpecLink.4.2.60" = "--5022012030321121350115031151";
        "AiPlayerbot.PremadeSpecLink.4.2.80" = "30532010114--5022012030321121350115031151";
        "AiPlayerbot.PremadeSpecName.4.3" = "as pvp";
        "AiPlayerbot.PremadeSpecGlyph.4.3" = "42974,43380,45768,43379,43376,42971";
        "AiPlayerbot.PremadeSpecLink.4.3.60" = "005303103342102522103031--50002";
        "AiPlayerbot.PremadeSpecLink.4.3.80" = "005303103342102522103031-004-532023203000012";
        "AiPlayerbot.PremadeSpecName.4.4" = "combat pvp";
        "AiPlayerbot.PremadeSpecGlyph.4.4" = "42972,43380,45762,43376,43378,42971";
        "AiPlayerbot.PremadeSpecLink.4.4.60" = "-3250002050225010223102321251";
        "AiPlayerbot.PremadeSpecLink.4.4.80" = "305120105-3250002050235010223102521251";
        "AiPlayerbot.PremadeSpecName.4.5" = "subtlety pvp";
        "AiPlayerbot.PremadeSpecGlyph.4.5" = "42968,43376,45764,43380,43379,42971";
        "AiPlayerbot.PremadeSpecLink.4.5.60" = "--5120212030320121330133221251";
        "AiPlayerbot.PremadeSpecLink.4.5.80" = "3023031-3-5120212030320121350135231251";

        #
        #
        ####################################################################################################

        ####################################################################################################
        # PRIEST
        #

        "AiPlayerbot.PremadeSpecName.5.0" = "disc pve";
        "AiPlayerbot.PremadeSpecGlyph.5.0" = "42408,43371,42400,43374,43342,45756";
        "AiPlayerbot.PremadeSpecLink.5.0.60" = "0503203130300512301323131051";
        "AiPlayerbot.PremadeSpecLink.5.0.80" = "0503203130300512331323231251-03520103";
        "AiPlayerbot.PremadeSpecName.5.1" = "holy pve";
        "AiPlayerbot.PremadeSpecGlyph.5.1" = "42408,43371,42400,43374,43342,42396";
        "AiPlayerbot.PremadeSpecLink.5.1.60" = "-035050031301152530000331331";
        "AiPlayerbot.PremadeSpecLink.5.1.80" = "05032031-235050032302152530000331351";
        "AiPlayerbot.PremadeSpecName.5.2" = "shadow pve";
        "AiPlayerbot.PremadeSpecGlyph.5.2" = "45753,43371,42407,43374,43370,42415";
        "AiPlayerbot.PremadeSpecLink.5.2.60" = "--325003041203010323150301351";
        "AiPlayerbot.PremadeSpecLink.5.2.80" = "0503203--325023051223010323152301351";
        "AiPlayerbot.PremadeSpecName.5.3" = "disc pvp";
        "AiPlayerbot.PremadeSpecGlyph.5.3" = "42408,43371,45760,43370,43374,45756";
        "AiPlayerbot.PremadeSpecLink.5.3.60" = "5003203130320512201323031051";
        "AiPlayerbot.PremadeSpecLink.5.3.80" = "5003203130322512331013231151-23050113";
        "AiPlayerbot.PremadeSpecName.5.4" = "holy pvp";
        "AiPlayerbot.PremadeSpecGlyph.5.4" = "42411,43371,42408,43370,43374,45755";
        "AiPlayerbot.PremadeSpecLink.5.4.60" = "-235501031000152430320031151";
        "AiPlayerbot.PremadeSpecLink.5.4.80" = "500320313-235501031000152530320031351";
        "AiPlayerbot.PremadeSpecName.5.5" = "shadow pvp";
        "AiPlayerbot.PremadeSpecGlyph.5.5" = "42407,43371,45753,43370,43374,42408";
        "AiPlayerbot.PremadeSpecLink.5.5.60" = "--005323241223112003102311351";
        "AiPlayerbot.PremadeSpecLink.5.5.80" = "50332031003--005323241223112003102311351";

        #
        #
        ####################################################################################################

        ####################################################################################################
        # DEATH KNIGHT
        #

        "AiPlayerbot.PremadeSpecName.6.0" = "blood pve";
        "AiPlayerbot.PremadeSpecGlyph.6.0" = "45805,43673,43538,43544,43672,43542";
        "AiPlayerbot.PremadeSpecLink.6.0.60" = "035502150300331320102013111-005";
        "AiPlayerbot.PremadeSpecLink.6.0.80" = "0055021533303310201020131-305020510002-00522";
        "AiPlayerbot.PremadeSpecName.6.1" = "frost pve";
        "AiPlayerbot.PremadeSpecGlyph.6.1" = "45805,43673,43547,43544,43672,43543";
        "AiPlayerbot.PremadeSpecLink.6.1.60" = "-32003350332203012300023101351";
        "AiPlayerbot.PremadeSpecLink.6.1.80" = "-32002350352203012300033101351-230200305003";
        "AiPlayerbot.PremadeSpecName.6.2" = "unholy pve";
        "AiPlayerbot.PremadeSpecGlyph.6.2" = "43542,43673,43546,43535,43672,43549";
        "AiPlayerbot.PremadeSpecLink.6.2.60" = "--2301303050032151000150013131151";
        "AiPlayerbot.PremadeSpecLink.6.2.80" = "23050202--2302303350032152000150003133151";
        "AiPlayerbot.PremadeSpecName.6.3" = "double aura blood pve";
        "AiPlayerbot.PremadeSpecGlyph.6.3" = "45805,43673,43538,43544,43672,43554";
        "AiPlayerbot.PremadeSpecLink.6.3.60" = "005512153330030320102013-305";
        "AiPlayerbot.PremadeSpecLink.6.3.80" = "005512153330030320102013-3050505002023001-002";
        "AiPlayerbot.PremadeSpecName.6.4" = "blood pvp";
        "AiPlayerbot.PremadeSpecGlyph.6.4" = "43534,43535,45799,43673,43672,45805";
        "AiPlayerbot.PremadeSpecLink.6.4.60" = "2305021503003313201222101351";
        "AiPlayerbot.PremadeSpecLink.6.4.80" = "2305021503003313201222101351--032232300023";
        "AiPlayerbot.PremadeSpecName.6.5" = "frost pvp";
        "AiPlayerbot.PremadeSpecGlyph.6.5" = "43543,43539,45800,43673,43672,45806";
        "AiPlayerbot.PremadeSpecLink.6.5.60" = "-32015351022203012001233101251";
        "AiPlayerbot.PremadeSpecLink.6.5.80" = "0055-32015351052203012001233131351-03";
        "AiPlayerbot.PremadeSpecName.6.6" = "unholy pvp";
        "AiPlayerbot.PremadeSpecGlyph.6.6" = "45804,43539,43549,43673,43672,45805";
        "AiPlayerbot.PremadeSpecLink.6.6.60" = "--2301323301002152230101203103151";
        "AiPlayerbot.PremadeSpecLink.6.6.80" = "-320050410002-2301323301002152230101203133151";

        #
        #
        ####################################################################################################

        ####################################################################################################
        # SHAMAN
        #

        "AiPlayerbot.PremadeSpecName.7.0" = "ele pve";
        "AiPlayerbot.PremadeSpecGlyph.7.0" = "41536,43385,41532,43386,44923,45776";
        "AiPlayerbot.PremadeSpecLink.7.0.60" = "4530001520213351102301351";
        "AiPlayerbot.PremadeSpecLink.7.0.80" = "4530001523213351302301351-00525003";
        "AiPlayerbot.PremadeSpecName.7.1" = "enh pve";
        "AiPlayerbot.PremadeSpecGlyph.7.1" = "41542,43385,41539,43386,43725,45771";
        "AiPlayerbot.PremadeSpecLink.7.1.60" = "-30305003105021333031121131051";
        "AiPlayerbot.PremadeSpecLink.7.1.80" = "053030152-30305003105021333031131131051";
        "AiPlayerbot.PremadeSpecName.7.2" = "resto pve";
        "AiPlayerbot.PremadeSpecGlyph.7.2" = "41527,43385,41517,43386,43725,45775";
        "AiPlayerbot.PremadeSpecLink.7.2.60" = "--50005301235310501102321251";
        "AiPlayerbot.PremadeSpecLink.7.2.80" = "-00502033-50005331335310501122331251";
        "AiPlayerbot.PremadeSpecName.7.3" = "ele pvp";
        "AiPlayerbot.PremadeSpecGlyph.7.3" = "45778,43388,45770,43725,43386,41524";
        "AiPlayerbot.PremadeSpecLink.7.3.60" = "0533001503213051322301341";
        "AiPlayerbot.PremadeSpecLink.7.3.80" = "0533051503213051322331351-023212001";
        "AiPlayerbot.PremadeSpecName.7.4" = "enh pvp";
        "AiPlayerbot.PremadeSpecGlyph.7.4" = "45778,43388,41526,43725,43344,45771";
        "AiPlayerbot.PremadeSpecLink.7.4.60" = "-02305203105001333201131131151";
        "AiPlayerbot.PremadeSpecLink.7.4.80" = "0503351-02305203105001333211131231251";
        "AiPlayerbot.PremadeSpecName.7.5" = "resto pvp";
        "AiPlayerbot.PremadeSpecGlyph.7.5" = "45778,43388,45775,43725,43344,41535";
        "AiPlayerbot.PremadeSpecLink.7.5.60" = "--05032331331013501120321251";
        "AiPlayerbot.PremadeSpecLink.7.5.80" = "-023222301004-05032331331013501120331251";

        #
        #
        ####################################################################################################

        ####################################################################################################
        # MAGE
        #

        "AiPlayerbot.PremadeSpecName.8.0" = "arcane pve";
        "AiPlayerbot.PremadeSpecGlyph.8.0" = "42735,43339,44955,43364,43361,42751";
        "AiPlayerbot.PremadeSpecLink.8.0.60" = "230005231100330150323102500321";
        "AiPlayerbot.PremadeSpecLink.8.0.80" = "230005231100330150323102505321-03-203303001";
        "AiPlayerbot.PremadeSpecName.8.1" = "fire pve";
        "AiPlayerbot.PremadeSpecGlyph.8.1" = "42739,43339,45737,43364,44920,42751";
        "AiPlayerbot.PremadeSpecLink.8.1.60" = "-0055030011302231053120321341";
        "AiPlayerbot.PremadeSpecLink.8.1.80" = "23000503110003-0055032012303330053120300351";
        "AiPlayerbot.PremadeSpecName.8.2" = "frost pve";
        "AiPlayerbot.PremadeSpecGlyph.8.2" = "42742,43339,50045,43364,43361,42751";
        "AiPlayerbot.PremadeSpecLink.8.2.60" = "--0533030313203100030152231151";
        "AiPlayerbot.PremadeSpecLink.8.2.80" = "23002303110003--0533030313203100030152231351";
        "AiPlayerbot.PremadeSpecName.8.3" = "frostfire pve";
        "AiPlayerbot.PremadeSpecGlyph.8.3" = "44684,44920,42751,43339,43364,45737";
        "AiPlayerbot.PremadeSpecLink.8.3.60" = "-2305032012303331053120300051";
        "AiPlayerbot.PremadeSpecLink.8.3.80" = "-2305032012303331053120321351-023302031";
        "AiPlayerbot.PremadeSpecName.8.4" = "arcane pvp";
        "AiPlayerbot.PremadeSpecGlyph.8.4" = "42735,43364,42738,43360,43357,42752";
        "AiPlayerbot.PremadeSpecLink.8.4.60" = "205323200122032103303102015221";
        "AiPlayerbot.PremadeSpecLink.8.4.80" = "205323200122032103303102015321-23002-303020301";
        "AiPlayerbot.PremadeSpecName.8.5" = "fire pvp";
        "AiPlayerbot.PremadeSpecGlyph.8.5" = "42738,43364,42752,43360,43357,45737";
        "AiPlayerbot.PremadeSpecLink.8.5.60" = "-2305202312020031223122301351";
        "AiPlayerbot.PremadeSpecLink.8.5.80" = "230321030122-2305212312020031223122301351";
        "AiPlayerbot.PremadeSpecName.8.6" = "frost pvp";
        "AiPlayerbot.PremadeSpecGlyph.8.6" = "42738,43364,45740,43357,43360,42752";
        "AiPlayerbot.PremadeSpecLink.8.6.60" = "--3533203210203100232102231151";
        "AiPlayerbot.PremadeSpecLink.8.6.80" = "23032103010203--3533203210203100232102231151";

        #
        #
        ####################################################################################################

        ####################################################################################################
        # WARLOCK
        #

        "AiPlayerbot.PremadeSpecName.9.0" = "affli pve";
        "AiPlayerbot.PremadeSpecGlyph.9.0" = "45785,43390,50077,43394,43393,45779";
        "AiPlayerbot.PremadeSpecLink.9.0.60" = "2350022001113510053500131151";
        "AiPlayerbot.PremadeSpecLink.9.0.70" = "2350022001113510053500131151--55";
        "AiPlayerbot.PremadeSpecLink.9.0.80" = "2350022001123510253500331151--55000005";
        "AiPlayerbot.PremadeSpecName.9.1" = "demo pve";
        "AiPlayerbot.PremadeSpecGlyph.9.1" = "45785,43390,50077,43394,43393,42459";
        "AiPlayerbot.PremadeSpecLink.9.1.60" = "-003203301135112530135201051";
        "AiPlayerbot.PremadeSpecLink.9.1.70" = "-003203301135112530135201051-55";
        "AiPlayerbot.PremadeSpecLink.9.1.80" = "-003203301135112530135221351-55000005";
        "AiPlayerbot.PremadeSpecName.9.2" = "destro pve";
        "AiPlayerbot.PremadeSpecGlyph.9.2" = "45785,43390,42454,43394,43393,42453";
        "AiPlayerbot.PremadeSpecLink.9.2.60" = "--05203215200231051305031151";
        "AiPlayerbot.PremadeSpecLink.9.2.80" = "23-0302-05203215220331051335231351";
        "AiPlayerbot.PremadeSpecName.9.3" = "affli pvp";
        "AiPlayerbot.PremadeSpecGlyph.9.3" = "50077,43392,42455,43390,43389,45783";
        "AiPlayerbot.PremadeSpecLink.9.3.60" = "0350002231223011053502301151";
        "AiPlayerbot.PremadeSpecLink.9.3.80" = "2350002231223111053502301151-2032003011302";
        "AiPlayerbot.PremadeSpecName.9.4" = "demo pvp";
        "AiPlayerbot.PremadeSpecGlyph.9.4" = "42459,43392,45780,43390,43389,45783";
        "AiPlayerbot.PremadeSpecLink.9.4.60" = "-003203301135202530135001251";
        "AiPlayerbot.PremadeSpecLink.9.4.80" = "-003203301135202530135011351-052300152";
        "AiPlayerbot.PremadeSpecName.9.5" = "destro pvp";
        "AiPlayerbot.PremadeSpecGlyph.9.5" = "42471,43392,42454,43390,43389,45783";
        "AiPlayerbot.PremadeSpecLink.9.5.60" = "--05230015220331351005031051";
        "AiPlayerbot.PremadeSpecLink.9.5.80" = "-2032003311302-05230015220331351005031051";

        #
        #
        ####################################################################################################

        ####################################################################################################
        # DRUID
        #

        "AiPlayerbot.PremadeSpecName.11.0" = "balance pve";
        "AiPlayerbot.PremadeSpecGlyph.11.0" = "40916,43331,40921,43335,44922,40919";
        "AiPlayerbot.PremadeSpecLink.11.0.60" = "5032003125031003213304301231";
        "AiPlayerbot.PremadeSpecLink.11.0.80" = "5032003125331303213305301231--205003012";
        "AiPlayerbot.PremadeSpecName.11.1" = "bear pve";
        "AiPlayerbot.PremadeSpecGlyph.11.1" = "40897,43331,46372,43335,43332,40899";
        "AiPlayerbot.PremadeSpecLink.11.1.60" = "-503232132322010303120300013501";
        "AiPlayerbot.PremadeSpecLink.11.1.80" = "-503232132322010353120303013511-20350001";
        "AiPlayerbot.PremadeSpecName.11.2" = "resto pve";
        "AiPlayerbot.PremadeSpecGlyph.11.2" = "40906,43331,45602,43335,43674,45603";
        "AiPlayerbot.PremadeSpecLink.11.2.60" = "--230033312031502331050313031";
        "AiPlayerbot.PremadeSpecLink.11.2.80" = "05320031--230033312031502431053313051";
        "AiPlayerbot.PremadeSpecName.11.3" = "cat pve";
        "AiPlayerbot.PremadeSpecGlyph.11.3" = "40902,43331,40901,43674,43335,45604";
        "AiPlayerbot.PremadeSpecLink.11.3.60" = "-552202032322010053100030310501";
        "AiPlayerbot.PremadeSpecLink.11.3.80" = "-553202032322010053120030310511-203503012";
        "AiPlayerbot.PremadeSpecName.11.4" = "balance pvp";
        "AiPlayerbot.PremadeSpecGlyph.11.4" = "40921,43331,45622,43674,43335,45623";
        "AiPlayerbot.PremadeSpecLink.11.4.60" = "5012203115331002213032311231";
        "AiPlayerbot.PremadeSpecLink.11.4.80" = "5022203125331003213035311231--230033012";
        "AiPlayerbot.PremadeSpecName.11.5" = "cat pvp";
        "AiPlayerbot.PremadeSpecGlyph.11.5" = "40902,43331,45601,43674,43335,40901";
        "AiPlayerbot.PremadeSpecLink.11.5.60" = "-513202032322010053103030310501";
        "AiPlayerbot.PremadeSpecLink.11.5.80" = "-523202032322010053103030310511-205503012";
        "AiPlayerbot.PremadeSpecName.11.6" = "resto pvp";
        "AiPlayerbot.PremadeSpecGlyph.11.6" = "40913,43331,40906,43335,43674,45623";
        "AiPlayerbot.PremadeSpecLink.11.6.60" = "--230033312031500511350013051";
        "AiPlayerbot.PremadeSpecLink.11.6.80" = "05320021--230033312031500531353013251";

        #
        #
        ####################################################################################################

        ###################################
        #                                 #
        # WORLD BUFFS                     #
        #                                 #
        ###################################

        ####################################################################################################
        #
        #

        # Applies automatically refreshing buffs to bots simulating effects of spells, flasks, food, runes, etc.
        # Requires sending the command "nc +worldbuff" in chat to a bot (or a group of bots) to enable
        # Each entry in the matrix should be formatted as follows: Entry:FactionID,ClassID,SpecID,MinimumLevel,MaximumLevel:SpellID1,SpellID2,etc.;
        # FactionID may be set to 0 for the entry to apply buffs to bots of either faction
        # The default entries create a cross-faction level 60-69 Vanilla buffs, level 70-79 TBC buffs, and level 80 buffs for each implemented pve spec from the "Premade Specs" section
        # The default entries may be deleted or modified, and new custom entries may be added

        "AiPlayerbot.WorldBuffMatrix" =
          "# WARRIOR ARMS 1:0,1,0,80,80:53760,57358; # WARRIOR FURY 2:0,1,1,80,80:53760,57358; # WARRIOR PROTECTION 3:0,1,2,80,80:53758,57356; # PALADIN HOLY 4:0,2,0,80,80:53749,57332,60347; # PALADIN PROTECTION 5:0,2,1,80,80:53758,57356; # PALADIN RETRIBUTION 6:0,2,2,80,80:53760,57371; # HUNTER BEAST 7:0,3,0,80,80:53760,57325; # HUNTER MARKSMANSHIP 8:0,3,1,80,80:53760,57358; # HUNTER SURVIVAL 9:0,3,2,80,80:53760,57367; # ROGUE ASSASSINATION 10:0,4,0,80,80:53760,57325; # ROGUE COMBAT 11:0,4,1,80,80:53760,57358; # ROGUE SUBTLETY 12:0,4,2,80,80:53760,57367; # PRIEST DISCIPLINE 13:0,5,0,80,80:53755,57327; # PRIEST HOLY 14:0,5,1,80,80:53755,57327; # PRIEST SHADOW 15:0,5,2,80,80:53755,57327; # DEATH KNIGHT BLOOD 16:0,6,0,80,80:53758,57356; # DEATH KNIGHT FROST 17:0,6,1,80,80:53760,57358; # DEATH KNIGHT UNHOLY 18:0,6,2,80,80:53760,57358; # DEATH KNIGHT BLOOD DPS 19:0,6,3,80,80:53760,57371; # SHAMAN ELEMENTAL 20:0,7,0,80,80:53755,57327; # SHAMAN ENHANCEMENT 21:0,7,1,80,80:53760,57325; # SHAMAN RESTORATION 22:0,7,2,80,80:53755,57327; # MAGE ARCANE 23:0,8,0,80,80:53755,57327; # MAGE FIRE 24:0,8,1,80,80:53755,57327; # MAGE FROST 25:0,8,2,80,80:53755,57327; # WARLOCK AFFLICTION 26:0,9,0,80,80:53755,57327; # WARLOCK DEMONOLOGY 27:0,9,1,80,80:53755,57327; # WARLOCK DESTRUCTION 28:0,9,2,80,80:53755,57327; # DRUID BALANCE 29:0,11,0,80,80:53755,57327; # DRUID FERAL BEAR 30:0,11,1,80,80:53749,53763,57367; # DRUID RESTORATION 31:0,11,2,80,80:54212,57334; # DRUID FERAL CAT 32:0,11,3,80,80:53760,57358; # WARRIOR ARMS TBC 33:0,1,0,70,79:28520,33256; # WARRIOR FURY TBC 34:0,1,1,70,79:28520,33256; # WARRIOR PROTECTION TBC 35:0,1,2,70,79:28518,33257; # PALADIN HOLY TBC 36:0,2,0,70,79:28491,39627,33263; # PALADIN PROTECTION TBC 37:0,2,1,70,79:28518,33257; # PALADIN RETRIBUTION TBC 38:0,2,2,70,79:28520,33256; # HUNTER BEAST TBC 39:0,3,0,70,79:28520,33261; # HUNTER MARKSMANSHIP TBC 40:0,3,1,70,79:28520,33261; # HUNTER SURVIVAL TBC 41:0,3,2,70,79:28520,33261; # ROGUE ASSASSINATION TBC 42:0,4,0,70,79:28520,33261; # ROGUE COMBAT TBC 43:0,4,1,70,79:28520,33261; # ROGUE SUBTLETY TBC 44:0,4,2,70,79:28520,33261; # PRIEST DISCIPLINE TBC 45:0,5,0,70,79:28491,39627,33263; # PRIEST HOLY TBC 46:0,5,1,70,79:28491,39627,33263; # PRIEST SHADOW TBC 47:0,5,2,70,79:28540,33263; # SHAMAN ELEMENTAL TBC 48:0,7,0,70,79:28521,33263; # SHAMAN ENHANCEMENT TBC 49:0,7,1,70,79:28520,33261; # SHAMAN RESTORATION TBC 50:0,7,2,70,79:28491,39627,33263; # MAGE ARCANE TBC 51:0,8,0,70,79:28521,33263; # MAGE FIRE TBC 52:0,8,1,70,79:28540,33263; # MAGE FROST TBC 53:0,8,2,70,79:28540,33263; # WARLOCK AFFLICTION TBC 54:0,9,0,70,79:28540,33263; # WARLOCK DEMONOLOGY TBC 55:0,9,1,70,79:28540,33263; # WARLOCK DESTRUCTION TBC 56:0,9,2,70,79:28540,33263; # DRUID BALANCE TBC 57:0,11,0,70,79:28521,33263; # DRUID FERAL BEAR TBC 58:0,11,1,70,79:28518,33257; # DRUID RESTORATION TBC 59:0,11,2,70,79:28491,39627,33263; # DRUID FERAL CAT TBC 60:0,11,3,70,79:28520,33261; # WARRIOR ARMS VANILLA 61:0,1,0,60,69:17538,24799; # WARRIOR FURY VANILLA 62:0,1,1,60,69:17538,24799; # WARRIOR PROTECTION VANILLA 63:0,1,2,60,69:17626,25661; # PALADIN HOLY VANILLA 64:0,2,0,60,69:17627,18194; # PALADIN PROTECTION VANILLA 65:0,2,1,60,69:17626,25661; # PALADIN RETRIBUTION VANILLA 66:0,2,2,60,69:17628,24799; # HUNTER BEAST VANILLA 67:0,3,0,60,69:17538,18192; # HUNTER MARKSMANSHIP VANILLA 68:0,3,1,60,69:17538,18192; # HUNTER SURVIVAL VANILLA 69:0,3,2,60,69:17538,18192; # ROGUE ASSASSINATION VANILLA 70:0,4,0,60,69:17538,18192; # ROGUE COMBAT VANILLA 71:0,4,1,60,69:17538,18192; # ROGUE SUBTLETY VANILLA 72:0,4,2,60,69:17538,18192; # PRIEST DISCIPLINE VANILLA 73:0,5,0,60,69:17628,18194; # PRIEST HOLY VANILLA 74:0,5,1,60,69:17627,18194; # PRIEST SHADOW VANILLA 75:0,5,2,60,69:17628,18194; # SHAMAN ELEMENTAL VANILLA 76:0,7,0,60,69:17628,18194; # SHAMAN ENHANCEMENT VANILLA 77:0,7,1,60,69:17538,24799; # SHAMAN RESTORATION VANILLA 78:0,7,2,60,69:17627,18194; # MAGE ARCANE VANILLA 79:0,8,0,60,69:17628,18194; # MAGE FIRE VANILLA 80:0,8,1,60,69:17628,18194; # MAGE FROST VANILLA 81:0,8,2,60,69:17628,18194; # WARLOCK AFFLICTION VANILLA 82:0,9,0,60,69:17628,25661; # WARLOCK DEMONOLOGY VANILLA 83:0,9,1,60,69:17628,25661; # WARLOCK DESTRUCTION VANILLA 84:0,9,2,60,69:17628,25661; # DRUID BALANCE VANILLA 85:0,11,0,60,69:17628,18194; # DRUID FERAL BEAR VANILLA 86:0,11,1,60,69:17626,25661; # DRUID RESTORATION VANILLA 87:0,11,2,60,69:17627,18194; # DRUID FERAL CAT VANILLA 88:0,11,3,60,69:17538,24799";

        #
        #
        ####################################################################################################

        ###################################
        #                                 #
        # RANDOMBOT DEFAULT TALENT SPECS  #
        #                                 #
        ###################################

        ####################################################################################################
        #
        #

        # AiPlayerbot.RandomClassSpecProb.<class>.<specno>  # The probability to choose the spec
        # AiPlayerbot.RandomClassSpecIndex.<class>.<specno> # The spec index in PremadeSpec

        #
        #
        ####################################################################################################

        ####################################################################################################
        # WARRIOR
        #

        # arms pve
        "AiPlayerbot.RandomClassSpecProb.1.0" = "20";
        "AiPlayerbot.RandomClassSpecIndex.1.0" = "0";
        # fury pve
        "AiPlayerbot.RandomClassSpecProb.1.1" = "40";
        "AiPlayerbot.RandomClassSpecIndex.1.1" = "1";
        # prot pve
        "AiPlayerbot.RandomClassSpecProb.1.2" = "40";
        "AiPlayerbot.RandomClassSpecIndex.1.2" = "2";
        # arms pvp
        "AiPlayerbot.RandomClassSpecProb.1.3" = "0";
        "AiPlayerbot.RandomClassSpecIndex.1.3" = "3";
        # fury pvp
        "AiPlayerbot.RandomClassSpecProb.1.4" = "0";
        "AiPlayerbot.RandomClassSpecIndex.1.4" = "4";
        # prot pvp
        "AiPlayerbot.RandomClassSpecProb.1.5" = "0";
        "AiPlayerbot.RandomClassSpecIndex.1.5" = "5";

        #
        #
        ####################################################################################################

        ####################################################################################################
        # PALADIN
        #

        # holy pve
        "AiPlayerbot.RandomClassSpecProb.2.0" = "30";
        "AiPlayerbot.RandomClassSpecIndex.2.0" = "0";
        # prot pve
        "AiPlayerbot.RandomClassSpecProb.2.1" = "40";
        "AiPlayerbot.RandomClassSpecIndex.2.1" = "1";
        # ret pve
        "AiPlayerbot.RandomClassSpecProb.2.2" = "30";
        "AiPlayerbot.RandomClassSpecIndex.2.2" = "2";
        # holy pvp
        "AiPlayerbot.RandomClassSpecProb.2.3" = "0";
        "AiPlayerbot.RandomClassSpecIndex.2.3" = "3";
        # prot pvp
        "AiPlayerbot.RandomClassSpecProb.2.4" = "0";
        "AiPlayerbot.RandomClassSpecIndex.2.4" = "4";
        # ret pvp
        "AiPlayerbot.RandomClassSpecProb.2.5" = "0";
        "AiPlayerbot.RandomClassSpecIndex.2.5" = "5";

        #
        #
        ####################################################################################################

        ####################################################################################################
        # HUNTER
        #

        # bm pve
        "AiPlayerbot.RandomClassSpecProb.3.0" = "33";
        "AiPlayerbot.RandomClassSpecIndex.3.0" = "0";
        # mm pve
        "AiPlayerbot.RandomClassSpecProb.3.1" = "33";
        "AiPlayerbot.RandomClassSpecIndex.3.1" = "1";
        # surv pve
        "AiPlayerbot.RandomClassSpecProb.3.2" = "33";
        "AiPlayerbot.RandomClassSpecIndex.3.2" = "2";
        # bm pvp
        "AiPlayerbot.RandomClassSpecProb.3.3" = "0";
        "AiPlayerbot.RandomClassSpecIndex.3.3" = "3";
        # mm pvp
        "AiPlayerbot.RandomClassSpecProb.3.4" = "0";
        "AiPlayerbot.RandomClassSpecIndex.3.4" = "4";
        # surv pvp
        "AiPlayerbot.RandomClassSpecProb.3.5" = "0";
        "AiPlayerbot.RandomClassSpecIndex.3.5" = "5";

        #
        #
        ####################################################################################################

        ####################################################################################################
        # ROGUE
        #

        # as pve
        "AiPlayerbot.RandomClassSpecProb.4.0" = "45";
        "AiPlayerbot.RandomClassSpecIndex.4.0" = "0";
        # combat pve
        "AiPlayerbot.RandomClassSpecProb.4.1" = "45";
        "AiPlayerbot.RandomClassSpecIndex.4.1" = "1";
        # subtlety pve
        "AiPlayerbot.RandomClassSpecProb.4.2" = "10";
        "AiPlayerbot.RandomClassSpecIndex.4.2" = "2";
        # as pvp
        "AiPlayerbot.RandomClassSpecProb.4.3" = "0";
        "AiPlayerbot.RandomClassSpecIndex.4.3" = "3";
        # combat pvp
        "AiPlayerbot.RandomClassSpecProb.4.4" = "0";
        "AiPlayerbot.RandomClassSpecIndex.4.4" = "4";
        # subtlety pvp
        "AiPlayerbot.RandomClassSpecProb.4.5" = "0";
        "AiPlayerbot.RandomClassSpecIndex.4.5" = "5";

        #
        #
        ####################################################################################################

        ####################################################################################################
        # PRIEST
        #

        # disc pve
        "AiPlayerbot.RandomClassSpecProb.5.0" = "40";
        "AiPlayerbot.RandomClassSpecIndex.5.0" = "0";
        # holy pve
        "AiPlayerbot.RandomClassSpecProb.5.1" = "35";
        "AiPlayerbot.RandomClassSpecIndex.5.1" = "1";
        # shadow pve
        "AiPlayerbot.RandomClassSpecProb.5.2" = "25";
        "AiPlayerbot.RandomClassSpecIndex.5.2" = "2";
        # disc pvp
        "AiPlayerbot.RandomClassSpecProb.5.3" = "0";
        "AiPlayerbot.RandomClassSpecIndex.5.3" = "3";
        # holy pvp
        "AiPlayerbot.RandomClassSpecProb.5.4" = "0";
        "AiPlayerbot.RandomClassSpecIndex.5.4" = "4";
        # shadow pvp
        "AiPlayerbot.RandomClassSpecProb.5.5" = "0";
        "AiPlayerbot.RandomClassSpecIndex.5.5" = "5";

        #
        #
        ####################################################################################################

        ####################################################################################################
        # DEATH KNIGHT
        #

        # blood pve
        "AiPlayerbot.RandomClassSpecProb.6.0" = "30";
        "AiPlayerbot.RandomClassSpecIndex.6.0" = "0";
        # frost pve
        "AiPlayerbot.RandomClassSpecProb.6.1" = "40";
        "AiPlayerbot.RandomClassSpecIndex.6.1" = "1";
        # unholy pve
        "AiPlayerbot.RandomClassSpecProb.6.2" = "30";
        "AiPlayerbot.RandomClassSpecIndex.6.2" = "2";
        # double aura blood pve
        "AiPlayerbot.RandomClassSpecProb.6.3" = "0";
        "AiPlayerbot.RandomClassSpecIndex.6.3" = "3";
        # blood pvp
        "AiPlayerbot.RandomClassSpecProb.6.4" = "0";
        "AiPlayerbot.RandomClassSpecIndex.6.4" = "4";
        # frost pvp
        "AiPlayerbot.RandomClassSpecProb.6.5" = "0";
        "AiPlayerbot.RandomClassSpecIndex.6.5" = "5";
        # unholy pvp
        "AiPlayerbot.RandomClassSpecProb.6.6" = "0";
        "AiPlayerbot.RandomClassSpecIndex.6.6" = "6";

        #
        #
        ####################################################################################################

        ####################################################################################################
        # SHAMAN
        #

        # ele pve
        "AiPlayerbot.RandomClassSpecProb.7.0" = "33";
        "AiPlayerbot.RandomClassSpecIndex.7.0" = "0";
        # enh pve
        "AiPlayerbot.RandomClassSpecProb.7.1" = "33";
        "AiPlayerbot.RandomClassSpecIndex.7.1" = "1";
        # resto pve
        "AiPlayerbot.RandomClassSpecProb.7.2" = "33";
        "AiPlayerbot.RandomClassSpecIndex.7.2" = "2";
        # ele pvp
        "AiPlayerbot.RandomClassSpecProb.7.3" = "0";
        "AiPlayerbot.RandomClassSpecIndex.7.3" = "3";
        # enh pvp
        "AiPlayerbot.RandomClassSpecProb.7.4" = "0";
        "AiPlayerbot.RandomClassSpecIndex.7.4" = "4";
        # resto pvp
        "AiPlayerbot.RandomClassSpecProb.7.5" = "0";
        "AiPlayerbot.RandomClassSpecIndex.7.5" = "5";

        #
        #
        ####################################################################################################

        ####################################################################################################
        # MAGE
        #

        # arcane pve
        "AiPlayerbot.RandomClassSpecProb.8.0" = "30";
        "AiPlayerbot.RandomClassSpecIndex.8.0" = "0";
        # fire pve
        "AiPlayerbot.RandomClassSpecProb.8.1" = "30";
        "AiPlayerbot.RandomClassSpecIndex.8.1" = "1";
        # frost pve
        "AiPlayerbot.RandomClassSpecProb.8.2" = "40";
        "AiPlayerbot.RandomClassSpecIndex.8.2" = "2";
        # frostfire pve
        "AiPlayerbot.RandomClassSpecProb.8.3" = "0";
        "AiPlayerbot.RandomClassSpecIndex.8.3" = "3";
        # arcane pvp
        "AiPlayerbot.RandomClassSpecProb.8.4" = "0";
        "AiPlayerbot.RandomClassSpecIndex.8.4" = "4";
        # fire pvp
        "AiPlayerbot.RandomClassSpecProb.8.5" = "0";
        "AiPlayerbot.RandomClassSpecIndex.8.5" = "5";
        # frost pvp
        "AiPlayerbot.RandomClassSpecProb.8.6" = "0";
        "AiPlayerbot.RandomClassSpecIndex.8.6" = "6";

        #
        #
        ####################################################################################################

        ####################################################################################################
        # WARLOCK
        #

        # affli pve
        "AiPlayerbot.RandomClassSpecProb.9.0" = "33";
        "AiPlayerbot.RandomClassSpecIndex.9.0" = "0";
        # demo pve
        "AiPlayerbot.RandomClassSpecProb.9.1" = "34";
        "AiPlayerbot.RandomClassSpecIndex.9.1" = "1";
        # destro pve
        "AiPlayerbot.RandomClassSpecProb.9.2" = "33";
        "AiPlayerbot.RandomClassSpecIndex.9.2" = "2";
        # affli pvp
        "AiPlayerbot.RandomClassSpecProb.9.3" = "0";
        "AiPlayerbot.RandomClassSpecIndex.9.3" = "3";
        # demo pvp
        "AiPlayerbot.RandomClassSpecProb.9.4" = "0";
        "AiPlayerbot.RandomClassSpecIndex.9.4" = "4";
        # destro pvp
        "AiPlayerbot.RandomClassSpecProb.9.5" = "0";
        "AiPlayerbot.RandomClassSpecIndex.9.5" = "5";

        #
        #
        ####################################################################################################

        ####################################################################################################
        # DRUID
        #

        # balance pve
        "AiPlayerbot.RandomClassSpecProb.11.0" = "20";
        "AiPlayerbot.RandomClassSpecIndex.11.0" = "0";
        # bear pve
        "AiPlayerbot.RandomClassSpecProb.11.1" = "25";
        "AiPlayerbot.RandomClassSpecIndex.11.1" = "1";
        # resto pve
        "AiPlayerbot.RandomClassSpecProb.11.2" = "35";
        "AiPlayerbot.RandomClassSpecIndex.11.2" = "2";
        # cat pve
        "AiPlayerbot.RandomClassSpecProb.11.3" = "20";
        "AiPlayerbot.RandomClassSpecIndex.11.3" = "3";
        # balance pvp
        "AiPlayerbot.RandomClassSpecProb.11.4" = "0";
        "AiPlayerbot.RandomClassSpecIndex.11.4" = "4";
        # cat pvp
        "AiPlayerbot.RandomClassSpecProb.11.5" = "0";
        "AiPlayerbot.RandomClassSpecIndex.11.5" = "5";
        # resto pvp
        "AiPlayerbot.RandomClassSpecProb.11.6" = "0";
        "AiPlayerbot.RandomClassSpecIndex.11.6" = "6";

        #
        #
        ####################################################################################################
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

      settings = {
        mysqld = (
          { }
          // (lib.optionalAttrs cfg.modules.playerbots.enable {
            skip-log-bin = true;
            innodb_buffer_pool_size = "2G";
            innodb_io_capacity = 500;
            innodb_io_capacity_max = 2500;
            innodb_log_file_size = "256M";
            transaction_isolation = "READ-COMMITTED";
            max_allowed_packet = "256M";
          })
        );
      };
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
