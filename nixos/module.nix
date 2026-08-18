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

  config = lib.mkIf cfg.enable {
    users.groups.acore = { };
    users.users.acore = {
      isSystemUser = true;
      group = "acore";
      home = "/var/lib/azerothcore";
    };

    environment.etc."azerothcore/authserver.conf".source = "${cfg.package}/etc/authserver.conf.dist";
    environment.etc."azerothcore/worldserver.conf".source = "${cfg.package}/etc/worldserver.conf.dist";

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
