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
            // hllib.workload-macros.workloadServiceHostPort config.kubetree.resources.flood.workload;
          };
        } spec
      )
      (
        lib.filterAttrs (name: value: cfg.integrations.${name}.enable) {
          sonarr = {
            apiEndpoint = "${hllib.workload-macros.workloadServiceUrl config.kubetree.resources.sonarr.workload}/api/v3/downloadclient";
            settings = cfg.integrations.sonarr.settings;
          };
          radarr = {
            apiEndpoint = "${hllib.workload-macros.workloadServiceUrl config.kubetree.resources.radarr.workload}/api/v3/downloadclient";
            settings = cfg.integrations.radarr.settings;
          };
          prowlarr = {
            apiEndpoint = "${hllib.workload-macros.workloadServiceUrl config.kubetree.resources.prowlarr.workload}/api/v1/downloadclient";
            settings = cfg.integrations.prowlarr.settings;
          };
        }
      );
  toApiKeyVar = name: "${lib.toUpper name}_API_KEY";
in
{
  options.homelab.flood.integrations = {
    sonarr = {
      enable = lib.mkOption {
        description = "Whether to integrate Flood with Sonarr";
        type = lib.types.bool;
        default = config.homelab.flood.enable && config.homelab.sonarr.enable;
        defaultText = lib.literalExpression "config.homelab.flood.enable && config.homelab.sonarr.enable";
      };
      settings = lib.mkOption {
        description = "Settings of the integration, the fields property will be converted from a attrSet to a name value pair array";
        type = lib.types.attrsOf lib.types.anything;
        default = { };
      };
    };
    radarr = {
      enable = lib.mkOption {
        description = "Whether to integrate Flood with Radarr";
        type = lib.types.bool;
        default = config.homelab.flood.enable && config.homelab.radarr.enable;
        defaultText = lib.literalExpression "config.homelab.flood.enable && config.homelab.radarr.enable";
      };
      settings = lib.mkOption {
        description = "Settings of the integration, the fields property will be converted from a attrSet to a name value pair array";
        type = lib.types.attrsOf lib.types.anything;
        default = { };
      };
    };
    prowlarr = {
      enable = lib.mkOption {
        description = "Whether to integrate Flood with Prowlarr";
        type = lib.types.bool;
        default = config.homelab.flood.enable && config.homelab.prowlarr.enable;
        defaultText = lib.literalExpression "config.homelab.flood.enable && config.homelab.prowlarr.enable";
      };
      settings = lib.mkOption {
        description = "Settings of the integration, the fields property will be converted from a attrSet to a name value pair array";
        type = lib.types.attrsOf lib.types.anything;
        default = { };
      };
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
