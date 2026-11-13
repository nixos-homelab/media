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
            // {
              host = "flood.flood";
              port = "3000";
            };
          };
        } spec
      )
      (
        lib.filterAttrs (name: value: cfg.integrations.${name}.enable) {
          sonarr = {
            apiEndpoint = "http://sonarr.sonarr:8989/api/v3/downloadclient";
            settings = cfg.integrations.sonarr.settings;
          };
          radarr = {
            apiEndpoint = "http://radarr.radarr:7878/api/v3/downloadclient";
            settings = cfg.integrations.radarr.settings;
          };
          prowlarr = {
            apiEndpoint = "http://prowlarr.prowlarr:9696/api/v1/downloadclient";
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
    # In the manifest of flood, as before
    homelab.kubernetes = lib.mkIf (integrations != [ ]) {
      submodules.instances.flood.config.submodules.instances = lib.listToAttrs (
        map (spec: {
          name = "integrate-${spec.name}";
          value = {
            submodule = "script";
            args = {
              script = self.lib.integration.mkArrStackIntegrationScript spec;
              allowEgress = [ spec.name ];
              container.envFrom = [ { secretRef.name = "api-keys"; } ];
            };
          };
        }) integrations
      );
    };
  };
}
