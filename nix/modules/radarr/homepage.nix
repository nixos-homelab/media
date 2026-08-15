{ inputs, self, ... }:
{
  lib,
  pkgs,
  config,
  ...
}:
let
  ccfg = config.homelab.cluster;
  cfg = config.homelab.homepage.integrations.radarr;
  hllib = inputs.homelab-shared.lib;
in
{
  options.homelab.homepage.integrations.radarr = {
    enable = lib.mkOption {
      description = "integration of radarr with homepage";
      type = lib.types.bool;
      default = config.homelab.radarr.enable && config.homelab.homepage.enable;
    };
  };
  imports = [
    inputs.setup-secrets.nixosModules.default
    inputs.homelab-shared.nixosModules.homepage
  ];
  config = lib.mkIf cfg.enable {
    setup-secrets.destinations = [
      {
        logPrefix = "Homepage (RADARR_API_KEY)";
        requires = [ "RADARR_API_KEY" ];
        cmd = hllib.setup-secrets.mkScript pkgs ''setKubeSecret homepage radarr-api-key HOMEPAGE_VAR_RADARR_API_KEY "''${RADARR_API_KEY:?}"'';
      }
    ];
    homelab.homepage = {
      services.Managers.Radarr = {
        sort = 70;
        icon = "radarr.png";
        description = "Movie library manager";
        href = "https://radarr.${ccfg.domain}";
        widget = {
          type = "radarr";
          url = self.lib.integration.workloadServiceUrl config.kubetree.resources.radarr.workload;
          key = "{{HOMEPAGE_VAR_RADARR_API_KEY}}";
        };
      };
      envFrom = [ { secretRef.name = "radarr-api-key"; } ];
      allowEgress = [ "radarr" ];
    };
  };
}
