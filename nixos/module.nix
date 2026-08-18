{ self }:
{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.services.acore;
in
{
  options.services.acore = {
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
      home = "/var/lib/acore";
    };

    environment.etc."acore/authserver.conf".source = "${cfg.package}/etc/authserver.conf.dist";
    environment.etc."acore/worldserver.conf".source = "${cfg.package}/etc/worldserver.conf.dist";

    systemd.services.auhtserver = {
      User = "acore";
      Group = "acore";

      StateDirectory = "acore";
      WorkingDirectory = "/var/lib/acore";

      ExecStart = "${cfg.package}/bin/authserver";
      Restart = "always";
    };

    systemd.services.worldserver = {
      User = "acore";
      Group = "acore";

      StateDirectory = "acore";
      WorkingDirectory = "/var/lib/acore";

      ExecStart = "${cfg.package}/bin/worldserver";
      Restart = "always";
    };
  };
}
