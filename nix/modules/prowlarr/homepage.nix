{ inputs, self, ... }:
{
  lib,
  pkgs,
  config,
  ...
}:
let
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
      (hllib.setup-secrets.kubeSecretDestination pkgs {
        logPrefix = "Homepage (PROWLARR_API_KEY)";
        namespace = "homepage";
        name = "prowlarr-api-key";
        data.HOMEPAGE_VAR_PROWLARR_API_KEY = "PROWLARR_API_KEY";
      })
    ];
    homelab.homepage = {
      sections.Media.enable = lib.mkDefault true;
      services.Media.Prowlarr = {
        enable = lib.mkDefault true;
        icon = "prowlarr.png";
        description = "Index scraper";
        href = "https://prowlarr.${config.homelab.workloads.domain}";
        widgets = [
          {
            type = "prowlarr";
            url = "http://prowlarr.prowlarr:9696";
            key = "{{HOMEPAGE_VAR_PROWLARR_API_KEY}}";
          }
        ];
      };
      envFrom = [ { secretRef.name = "prowlarr-api-key"; } ];
      allowEgress = [ "prowlarr" ];
    };
  };
}
