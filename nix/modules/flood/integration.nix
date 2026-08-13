{ inputs, self, ... }:
{
  pkgs,
  lib,
  config,
  ...
}:
with builtins;
let
  cfg = config.homelab.flood;
  hllib = inputs.homelab-shared.lib;
  integrations =
    lib.mapAttrsToList
      (
        name: spec:
        lib.recursiveUpdate {
          inherit name;
          authApiKeyVar = toApiKeyVar name;
          settings = {
            name = "Flood";
            enable = true;
            implementation = "Flood";
            implementationName = "Flood";
            configContract = "FloodSettings";
            priority = 1;
            protocol = "torrent";
            categories = [ ];
            supportsCategories = true;
            removeCompletedDownloads = true;
            removeFailedDownloads = true;
            fields = {
              tags = [ name ];
              destination = "/torrents/";
            }
            // self.lib.integration.workloadServiceHostPort config.kubetree.resources.flood.workload;
          };
        } spec
      )
      (
        lib.filterAttrs (name: value: cfg.integrations.${name}.enable) {
          sonarr.apiEndpoint = "${self.lib.integration.workloadServiceUrl config.kubetree.resources.sonarr.workload}/api/v3/downloadclient";
          radarr.apiEndpoint = "${self.lib.integration.workloadServiceUrl config.kubetree.resources.radarr.workload}/api/v3/downloadclient";
          prowlarr.apiEndpoint = "${self.lib.integration.workloadServiceUrl config.kubetree.resources.prowlarr.workload}/api/v1/downloadclient";
        }
      );
  toApiKeyVar = name: "${lib.toUpper name}_API_KEY";
in
{
  options.homelab.flood.integrations = {
    sonarr.enable = lib.mkOption {
      description = "Whether to integrate Flood with Sonarr";
      type = lib.types.bool;
      default = config.homelab.flood.enable && config.homelab.sonarr.enable;
    };
    radarr.enable = lib.mkOption {
      description = "Whether to integrate Flood with Radarr";
      type = lib.types.bool;
      default = config.homelab.flood.enable && config.homelab.radarr.enable;
    };
    prowlarr.enable = lib.mkOption {
      description = "Whether to integrate Flood with Prowlarr";
      type = lib.types.bool;
      default = config.homelab.flood.enable && config.homelab.sonarr.enable;
    };
  };
  config = {
    setup-secrets.destinations = [
      {
        logPrefix = "Flood integration keys";
        requires = (catAttrs "authApiKeyVar" integrations);
        cmd = hllib.setup-secrets.mkScript pkgs ''
          setKubeSecret flood api-keys \
            ${lib.join " \\\n  " (
              map (key: ''${key} "''${${key}:?}"'') (catAttrs "authApiKeyVar" integrations)
            )}
        '';
      }
    ];
    kubetree.resources.flood = lib.mergeAttrsList (
      map (spec: {
        "${spec.name}-integration" = {
          apiVersion = "cluster.local";
          kind = "ScriptMacro";
          metadata.namespace = "flood";
          metadata.name = "integrate-${spec.name}";
          spec.allowEgress = [ spec.name ];
          spec.script = self.lib.integration.mkArrStackIntegrationScript spec;
          spec.podSpecMacro.mainContainer.envFrom = [ { secretRef.name = "api-keys"; } ];
        };
      }) integrations
    );
  };
}
