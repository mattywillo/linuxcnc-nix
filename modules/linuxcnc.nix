{ config, lib, pkgs, ... }:
let
  cfg = config.local.packages.linuxcnc;
  inherit (builtins) filter map pathExists listToAttrs;
in {
  options.local.packages.linuxcnc.enable = lib.mkEnableOption "Enable linuxcnc";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [ linuxcnc ];

    security.wrappers = listToAttrs (map (f: {
      name = f;
      value = {
        setuid = true;
        owner = "root";
        group = "root";
        source = "${pkgs.linuxcnc}/bin/${f}-nosetuid";
      };
    }) (filter (f: pathExists "${pkgs.linuxcnc}/bin/${f}-nosetuid") pkgs.linuxcnc.setuidApps));
  };
}
