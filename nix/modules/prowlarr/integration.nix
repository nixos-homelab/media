{ inputs, self, ... }:
{
  pkgs,
  lib,
  config,
  ...
}:
with builtins;
let
  cfg = config.homelab.prowlarr;
  hllib = inputs.homelab-shared.lib;
  prowlarrUrl = self.lib.integration.workloadServiceUrl config.kubetree.resources.prowlarr.workload;
  integrations =
    lib.mapAttrsToList
      (
        name: spec:
        lib.recursiveUpdate (
          let
            hasApiKey = lib.attrByPath [ "hasApiKey" ] true spec;
          in
          {
            inherit name hasApiKey;
            title = self.lib.integration.capitalize name;
            authApiKeyVar = "PROWLARR_API_KEY";
            apiUrl = prowlarrUrl;
          }
          // (lib.optionalAttrs hasApiKey { apiKeyVar = "${lib.toUpper name}_API_KEY"; })
          // ({
            applications.extraSettings = {
              syncLevel = "fullSync";
              fields = {
                prowlarrUrl = prowlarrUrl;
                baseUrl = self.lib.integration.workloadServiceUrl config.kubetree.resources.${name}.workload;
              };
            };
            downloadclient.extraSettings = {
              priority = 1;
              categories = [ ];
              supportsCategories = true;
              fields = self.lib.integration.workloadServiceHostPort config.kubetree.resources.${name}.workload;
            };
          }).${spec.apiType}
        ) spec
      )
      (
        lib.filterAttrs (name: spec: cfg.integrations.${name}.enable) {
          sonarr.apiType = "applications";
          radarr.apiType = "applications";
          flood = {
            apiType = "downloadclient";
            hasApiKey = false;
            extraSettings = {
              protocol = "torrent";
              fields.tags = [ "prowlarr" ];
            };
          };
          sabnzbd = {
            apiType = "downloadclient";
            extraSettings = {
              protocol = "usenet";
              fields.category = "prowlarr";
            };
          };
        }
      );
in
{
  options.homelab.prowlarr.integrations = {
    sonarr.enable = lib.mkOption {
      description = "Whether to integrate Prowlarr with Sonarr";
      type = lib.types.bool;
      default = config.homelab.prowlarr.enable && config.homelab.sonarr.enable;
    };
    radarr.enable = lib.mkOption {
      description = "Whether to integrate Prowlarr with Radarr";
      type = lib.types.bool;
      default = config.homelab.prowlarr.enable && config.homelab.radarr.enable;
    };
    flood.enable = lib.mkOption {
      description = "Whether to integrate Prowlarr with Flood";
      type = lib.types.bool;
      default = config.homelab.prowlarr.enable && config.homelab.flood.enable;
    };
    sabnzbd.enable = lib.mkOption {
      description = "Whether to integrate Prowlarr with SABnzbd";
      type = lib.types.bool;
      default = config.homelab.prowlarr.enable && config.homelab.sabnzbd.enable;
    };
  };
  config = {
    setup-secrets.destinations = [
      {
        logPrefix = "Prowlarr integration keys";
        requires = [ "PROWLARR_API_KEY" ] ++ (catAttrs "apiKeyVar" integrations);
        cmd = hllib.setup-secrets.mkScript pkgs ''
          setKubeSecret prowlarr api-keys \
            PROWLARR_API_KEY "''${PROWLARR_API_KEY:?}" \
            ${lib.join " \\\n  " (map (key: ''${key} "''${${key}:?}"'') (catAttrs "apiKeyVar" integrations))}
        '';
      }
    ];
    kubetree.resources.prowlarr = lib.mergeAttrsList (
      map (spec: {
        "${spec.name}-integration" = self.lib.integration.mkIntegrationJob spec;
      }) integrations
    );
  };
}
