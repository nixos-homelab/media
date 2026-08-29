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
  integrations =
    lib.mapAttrsToList
      (
        name: spec:
        lib.recursiveUpdate {
          inherit name;
          authApiKeyVar = "PROWLARR_API_KEY";
          apiKeyFieldName = "apiKey";
          apiKeyVar = toApiKeyVar name;
          apiEndpoint = "${hllib.workload-macros.workloadServiceUrl config.kubetree.resources.prowlarr.workload}/api/v1/applications";
          settings = {
            enable = true;
            syncLevel = "fullSync";
            fields = {
              prowlarrUrl = hllib.workload-macros.workloadServiceUrl config.kubetree.resources.prowlarr.workload;
              baseUrl = hllib.workload-macros.workloadServiceUrl config.kubetree.resources.${name}.workload;
            };
          };
        } spec
      )
      (
        lib.filterAttrs (name: value: cfg.integrations.${name}.enable) {
          sonarr.settings = cfg.integrations.sonarr.settings // {
            name = "Sonarr";
            implementationName = "Sonarr";
            implementation = "Sonarr";
            configContract = "SonarrSettings";
          };
          radarr.settings = cfg.integrations.radarr.settings // {
            name = "Radarr";
            implementationName = "Radarr";
            implementation = "Radarr";
            configContract = "RadarrSettings";
          };
        }
      );
  toApiKeyVar = name: "${lib.toUpper name}_API_KEY";
in
{
  options.homelab.prowlarr.integrations = {
    sonarr = {
      enable = lib.mkOption {
        description = "Whether to integrate Prowlarr with Sonarr";
        type = lib.types.bool;
        default = config.homelab.prowlarr.enable && config.homelab.sonarr.enable;
        defaultText = lib.literalExpression "config.homelab.prowlarr.enable && config.homelab.sonarr.enable";
      };
      settings = lib.mkOption {
        description = "Settings of the integration, the fields property will be converted from a attrSet to a name value pair array";
        type = lib.types.attrsOf lib.types.anything;
        default = { };
      };
    };

    radarr = {
      enable = lib.mkOption {
        description = "Whether to integrate Prowlarr with Radarr";
        type = lib.types.bool;
        default = config.homelab.prowlarr.enable && config.homelab.radarr.enable;
        defaultText = lib.literalExpression "config.homelab.prowlarr.enable && config.homelab.radarr.enable";
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
        "${spec.name}-integration" = {
          apiVersion = "cluster.local";
          kind = "ScriptMacro";
          metadata.namespace = "prowlarr";
          metadata.name = "integrate-${spec.name}";
          spec.allowEgress = [ "prowlarr" ];
          spec.script = self.lib.integration.mkArrStackIntegrationScript spec;
          spec.podSpecMacro.mainContainer.envFrom = [ { secretRef.name = "api-keys"; } ];
        };
      }) integrations
    );
  };
}
