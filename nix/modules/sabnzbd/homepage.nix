{ inputs, self, ... }:
{
  lib,
  pkgs,
  config,
  ...
}:
let
  ccfg = config.homelab.cluster;
  cfg = config.homelab.homepage.integrations.sabnzbd;
  hllib = inputs.homelab-shared.lib;
in
{
  options.homelab.homepage.integrations.sabnzbd = {
    enable = lib.mkOption {
      description = "integration of sabnzbd with homepage";
      type = lib.types.bool;
      default = config.homelab.sabnzbd.enable && config.homelab.homepage.enable;
      defaultText = lib.literalExpression "config.homelab.sabnzbd.enable && config.homelab.homepage.enable";
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
        logPrefix = "Homepage (SABNZBD_API_KEY)";
        requires = [ "SABNZBD_API_KEY" ];
        cmd = hllib.setup-secrets.mkScript pkgs ''setKubeSecret homepage sabnzbd-api-key HOMEPAGE_VAR_SABNZBD_API_KEY "''${SABNZBD_API_KEY:?}"'';
      }
    ];
    homelab.homepage = {
      sections.Media.enable = lib.mkDefault true;
      services.Media.SABnzbd = {
        enable = lib.mkDefault true;
        icon = "sabnzbd.png";
        description = "The automated Usenet download tool ";
        href = "https://sabnzbd.${ccfg.domain}";
        widgets = [
          {
            type = "sabnzbd";
            url = self.lib.integration.workloadServiceUrl config.kubetree.resources.sabnzbd.workload;
            key = "{{HOMEPAGE_VAR_SABNZBD_API_KEY}}";
          }
        ];
      };
      envFrom = [ { secretRef.name = "sabnzbd-api-key"; } ];
      allowEgress = [ "sabnzbd" ];
    };
  };
}
