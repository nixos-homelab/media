{ inputs, ... }:
{
  lib,
  config,
  ...
}:
let
  ccfg = config.homelab.cluster;
  cfg = config.homelab.workloads.homepage.integrations.flood;
in
{
  options.homelab.workloads.homepage.integrations.flood = {
    enable = lib.mkOption {
      description = "integration of flood with homepage";
      type = lib.types.bool;
      default = config.homelab.workloads.flood.enable && config.homelab.workloads.homepage.enable;
    };
  };
  imports = [ inputs.homelab-shared.nixosModules.homepage ];
  config = lib.mkIf cfg.enable {
    homelab.workloads.homepage = {
      services.Download.Flood = {
        icon = "flood.png";
        description = "rTorrent WebUI";
        href = "https://flood.${ccfg.domain}";
        widget = {
          type = "flood";
          url = "http://flood.flood:3000";
        };
      };
      allowEgress = [ "flood" ];
    };
  };
}
