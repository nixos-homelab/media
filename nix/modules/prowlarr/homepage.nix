{ inputs, self, ... }:
{
  lib,
  pkgs,
  config,
  ...
}:
let
  ccfg = config.homelab.cluster;
  cfg = config.homelab.homepage.integrations.prowlarr;
  hllib = inputs.homelab-shared.lib;
in
{
  options.homelab.homepage.integrations.prowlarr = {
    enable = lib.mkOption {
      description = "Whether to integrate Prowlarr with homepage";
      type = lib.types.bool;
      default = config.homelab.prowlarr.enable && config.homelab.homepage.enable;
      defaultText = lib.literalExpression "config.homelab.prowlarr.enable && config.homelab.homepage.enable";
    };
  };
  imports = [
    inputs.setup-secrets.nixosModules.default
    inputs.homelab-shared.nixosModules.homepage
    self.nixosModules.homepage
  ];
  config = lib.mkIf cfg.enable {
    setup-secrets.destinations = [
      {
        logPrefix = "Homepage (PROWLARR_API_KEY)";
        requires = [ "PROWLARR_API_KEY" ];
        cmd = hllib.setup-secrets.mkScript pkgs ''setKubeSecret homepage prowlarr-api-key HOMEPAGE_VAR_PROWLARR_API_KEY "''${PROWLARR_API_KEY:?}"'';
      }
    ];
    homelab.homepage = {
      sections.Media.enable = lib.mkDefault true;
      services.Media.Prowlarr = {
        enable = lib.mkDefault true;
        icon = "prowlarr.png";
        description = "Index scraper";
        href = "https://prowlarr.${ccfg.domain}";
        widgets = [
          {
            type = "prowlarr";
            url = self.lib.integration.workloadServiceUrl config.kubetree.resources.prowlarr.workload;
            key = "{{HOMEPAGE_VAR_PROWLARR_API_KEY}}";
          }
        ];
      };
      envFrom = [ { secretRef.name = "prowlarr-api-key"; } ];
      allowEgress = [ "prowlarr" ];
    };
  };
}
