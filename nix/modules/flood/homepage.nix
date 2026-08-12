{ inputs, self, ... }:
{
  lib,
  config,
  ...
}:
let
  ccfg = config.homelab.cluster;
  cfg = config.homelab.homepage.integrations.flood;
in
{
  options.homelab.homepage.integrations.flood = {
    enable = lib.mkOption {
      description = "integration of flood with homepage";
      type = lib.types.bool;
      default = config.homelab.flood.enable && config.homelab.homepage.enable;
    };
  };
  imports = [ inputs.homelab-shared.nixosModules.homepage ];
  config = lib.mkIf cfg.enable {
    homelab.homepage = {
      services.Download.Flood = {
        icon = "flood.png";
        description = "rTorrent WebUI";
        href = "https://flood.${ccfg.domain}";
        widget = {
          type = "flood";
          url = self.lib.integration.workloadServiceUrl config.kubetree.resources.flood.workload;
        };
      };
      allowEgress = [ "flood" ];
    };
  };
}
