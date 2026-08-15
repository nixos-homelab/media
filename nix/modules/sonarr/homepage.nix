{ inputs, self, ... }:
{
  lib,
  pkgs,
  config,
  ...
}:
let
  ccfg = config.homelab.cluster;
  cfg = config.homelab.homepage.integrations.sonarr;
  hllib = inputs.homelab-shared.lib;
in
{
  options.homelab.homepage.integrations.sonarr = {
    enable = lib.mkOption {
      description = "integration of sonarr with homepage";
      type = lib.types.bool;
      default = config.homelab.sonarr.enable && config.homelab.homepage.enable;
    };
  };
  imports = [
    inputs.setup-secrets.nixosModules.default
    inputs.homelab-shared.nixosModules.homepage
  ];
  config = lib.mkIf cfg.enable {
    setup-secrets.destinations = [
      {
        logPrefix = "Homepage (SONARR_API_KEY)";
        requires = [ "SONARR_API_KEY" ];
        cmd = hllib.setup-secrets.mkScript pkgs ''setKubeSecret homepage sonarr-api-key HOMEPAGE_VAR_SONARR_API_KEY "''${SONARR_API_KEY:?}"'';
      }
    ];
    homelab.homepage = {
      services.Managers.Sonarr = {
        sort = 50;
        icon = "sonarr.png";
        description = "TV Show library manager";
        href = "https://sonarr.${ccfg.domain}";
        widget = {
          type = "sonarr";
          url = self.lib.integration.workloadServiceUrl config.kubetree.resources.sonarr.workload;
          key = "{{HOMEPAGE_VAR_SONARR_API_KEY}}";
        };
      };
      envFrom = [ { secretRef.name = "sonarr-api-key"; } ];
      allowEgress = [ "sonarr" ];
    };
  };
}
