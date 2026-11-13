{ inputs, self, ... }:
{
  pkgs,
  lib,
  config,
  ...
}:
with builtins;
let
  cfg = config.homelab.plex;
  hllib = inputs.homelab-shared.lib;
  integrations =
    lib.mapAttrsToList
      (
        name: spec:
        lib.recursiveUpdate {
          inherit name;
          authApiKeyVar = toApiKeyVar name;
          apiKeyFieldName = "authToken";
          apiKeyVar = "PLEX_API_KEY";
          apiEndpoint = "${serviceUrls.${name}}/api/v3/notification";
          settings = {
            name = "Plex Media Server";
            enable = true;
            implementation = "PlexServer";
            implementationName = "Plex Media Server";
            configContract = "PlexServerSettings";
            fields = {
              host = "plex.plex";
              port = 32400;
              updateLibrary = true;
            };
          };
        } spec
      )
      (
        lib.filterAttrs (name: value: cfg.integrations.${name}.enable) {
          sonarr.settings = cfg.integrations.sonarr.settings // {
            onUpgrade = true;
            onImportComplete = true;
          };
          radarr.settings = cfg.integrations.radarr.settings // {
            onDownload = true;
            onUpgrade = true;
          };
        }
      );
  toApiKeyVar = name: "${lib.toUpper name}_API_KEY";
  serviceUrls = {
    sonarr = "http://sonarr.sonarr:8989";
    radarr = "http://radarr.radarr:7878";
  };
in
{
  options.homelab.plex.integrations = {
    sonarr = {
      enable = lib.mkOption {
        description = "Whether to integrate Plex with Sonarr";
        type = lib.types.bool;
        default = config.homelab.plex.enable && config.homelab.sonarr.enable;
        defaultText = lib.literalExpression "config.homelab.plex.enable && config.homelab.sonarr.enable";
      };
      settings = lib.mkOption {
        description = "Settings of the integration, the fields property will be converted from a attrSet to a name value pair array";
        type = lib.types.attrsOf lib.types.anything;
        default = { };
      };
    };

    radarr = {
      enable = lib.mkOption {
        description = "Whether to integrate Plex with Radarr";
        type = lib.types.bool;
        default = config.homelab.plex.enable && config.homelab.radarr.enable;
        defaultText = lib.literalExpression "config.homelab.plex.enable && config.homelab.radarr.enable";
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
        logPrefix = "Plex integration keys";
        requires = [ "PLEX_API_KEY" ] ++ (catAttrs "authApiKeyVar" integrations);
        cmd = hllib.setup-secrets.mkScript pkgs ''
          setKubeSecret plex api-keys \
            PLEX_API_KEY "''${PLEX_API_KEY:?}" \
            ${lib.join " \\\n  " (
              map (key: ''${key} "''${${key}:?}"'') (catAttrs "authApiKeyVar" integrations)
            )}
        '';
      }
    ];
    # In the manifest of plex, as before
    homelab.kubernetes = lib.mkIf (integrations != [ ]) {
      submodules.instances.plex.config.submodules.instances = lib.listToAttrs (
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
