{ inputs, self, ... }:
{
  lib,
  pkgs,
  config,
  ...
}:
let
  ccfg = config.homelab.cluster;
  cfg = config.homelab.homepage.integrations.plex;
  hllib = inputs.homelab-shared.lib;
in
{
  options.homelab.homepage.integrations.plex = {
    enable = lib.mkOption {
      description = "integration of Plex with homepage";
      type = lib.types.bool;
      default = config.homelab.plex.enable && config.homelab.homepage.enable;
      defaultText = lib.literalExpression "config.homelab.plex.enable && config.homelab.homepage.enable";
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
        logPrefix = "Homepage (PLEX_API_KEY)";
        requires = [ "PLEX_API_KEY" ];
        cmd = hllib.setup-secrets.mkScript pkgs ''setKubeSecret homepage plex-api-key HOMEPAGE_VAR_PLEX_API_KEY "''${PLEX_API_KEY:?}"'';
      }
    ];
    homelab.homepage = {
      sections.Media.enable = lib.mkDefault true;
      services.Media.Plex = {
        enable = lib.mkDefault true;
        icon = "plex.png";
        description = "Media center";
        href = "https://plex.${ccfg.domain}";
        widgets = [
          {
            type = "plex";
            url = "https://plex.plex:32400";
            fields = [
              "streams"
              "movies"
              "tv"
            ];
            key = "{{HOMEPAGE_VAR_PLEX_API_KEY}}";
          }
        ];
      };
      envFrom = [ { secretRef.name = "plex-api-key"; } ];
      allowEgress = [ "plex" ];
    };
  };
}
