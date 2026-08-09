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
    };
  };
  imports = [
    inputs.setup-secrets.nixosModules.default
    inputs.homelab-shared.nixosModules.homepage
  ];
  config = lib.mkIf cfg.enable {
    setup-secrets.destinations = [
      {
        logPrefix = "Homepage (SABNZBD_API_KEY)";
        requires = [ "SABNZBD_API_KEY" ];
        cmd = hllib.setup-secrets.mkScript pkgs ''setKubeSecret homepage sabnzbd-api-key SABNZBD_API_KEY "''${SABNZBD_API_KEY:?}"'';
      }
    ];
    homelab.homepage = {
      services.Download.SABnzbd = {
        sort = 50;
        icon = "sabnzbd.png";
        description = "The automated Usenet download tool ";
        href = "https://sabnzbd.${ccfg.domain}";
        widget = {
          type = "sabnzbd";
          url = "http://sabnzbd.sabnzbd:8080";
          key = "{{HOMEPAGE_VAR_SABNZBD_API_KEY}}";
        };
      };
      envByName.HOMEPAGE_VAR_SABNZBD_API_KEY.valueFrom.secretKeyRef = {
        name = "sabnzbd-api-key";
        key = "SABNZBD_API_KEY";
      };
      allowEgress = [ "sabnzbd" ];
    };
  };
}
