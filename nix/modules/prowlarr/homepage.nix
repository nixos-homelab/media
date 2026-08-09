{ inputs, self, ... }:
{
  lib,
  pkgs,
  config,
  ...
}:
let
  ccfg = config.homelab.cluster;
  cfg = config.homelab.workloads.homepage.integrations.prowlarr;
  hllib = inputs.homelab-shared.lib;
in
{
  options.homelab.workloads.homepage.integrations.prowlarr = {
    enable = lib.mkOption {
      description = "integration of prowlarr with homepage";
      type = lib.types.bool;
      default = config.homelab.workloads.prowlarr.enable && config.homelab.workloads.homepage.enable;
    };
  };
  imports = [
    inputs.setup-secrets.nixosModules.default
    inputs.homelab-shared.nixosModules.homepage
  ];
  config = lib.mkIf cfg.enable {
    setup-secrets.destinations = [
      {
        logPrefix = "Homepage (PROWLARR_API_KEY)";
        requires = [ "PROWLARR_API_KEY" ];
        cmd = hllib.setup-secrets.mkScript pkgs ''setKubeSecret homepage prowlarr-api-key PROWLARR_API_KEY "''${PROWLARR_API_KEY:?}"'';
      }
    ];
    homelab.workloads.homepage = {
      services.Managers.Prowlarr = {
        sort = 200;
        icon = "prowlarr.png";
        description = "Index scraper";
        href = "https://prowlarr.${ccfg.domain}";
        widget = {
          type = "prowlarr";
          url = "http://prowlarr.prowlarr:9696";
          key = "{{HOMEPAGE_VAR_PROWLARR_API_KEY}}";
        };
      };
      envByName.HOMEPAGE_VAR_PROWLARR_API_KEY.valueFrom.secretKeyRef = {
        name = "prowlarr-api-key";
        key = "PROWLARR_API_KEY";
      };
      allowEgress = [ "prowlarr" ];
    };
  };
}
