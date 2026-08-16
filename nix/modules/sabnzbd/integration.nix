{ inputs, self, ... }:
{
  pkgs,
  lib,
  config,
  ...
}:
with builtins;
let
  cfg = config.homelab.sabnzbd;
  hllib = inputs.homelab-shared.lib;
  integrations =
    lib.mapAttrsToList
      (
        name: spec:
        lib.recursiveUpdate {
          inherit name;
          authApiKeyVar = toApiKeyVar name;
          apiKeyFieldName = "apiKey";
          apiKeyVar = "SABNZBD_API_KEY";
          settings = {
            name = "SABnzbd";
            enable = true;
            implementation = "Sabnzbd";
            implementationName = "SABnzbd";
            configContract = "SabnzbdSettings";
            priority = 1;
            protocol = "usenet";
            categories = [ ];
            supportsCategories = true;
            removeCompletedDownloads = true;
            removeFailedDownloads = true;
            fields = self.lib.integration.workloadServiceHostPort config.kubetree.resources.sabnzbd.workload;
          };
        } spec
      )
      (
        lib.filterAttrs (name: value: cfg.integrations.${name}.enable) {
          sonarr = {
            apiEndpoint = "${self.lib.integration.workloadServiceUrl config.kubetree.resources.sonarr.workload}/api/v3/downloadclient";
            settings.fields.category = "tv";
          };
          radarr = {
            apiEndpoint = "${self.lib.integration.workloadServiceUrl config.kubetree.resources.radarr.workload}/api/v3/downloadclient";
            settings.fields.category = "movies";
          };
          prowlarr.apiEndpoint = "${self.lib.integration.workloadServiceUrl config.kubetree.resources.prowlarr.workload}/api/v1/downloadclient";
        }
      );
  toApiKeyVar = name: "${lib.toUpper name}_API_KEY";
in
{
  options.homelab.sabnzbd.integrations = {
    sonarr.enable = lib.mkOption {
      description = "Whether to integrate SABNzbd with Sonarr";
      type = lib.types.bool;
      default = config.homelab.sabnzbd.enable && config.homelab.sonarr.enable;
      defaultText = lib.literalExpression "config.homelab.sabnzbd.enable && config.homelab.sonarr.enable";
    };
    radarr.enable = lib.mkOption {
      description = "Whether to integrate SABNzbd with Radarr";
      type = lib.types.bool;
      default = config.homelab.sabnzbd.enable && config.homelab.radarr.enable;
      defaultText = lib.literalExpression "config.homelab.sabnzbd.enable && config.homelab.radarr.enable";
    };
    prowlarr.enable = lib.mkOption {
      description = "Whether to integrate SABNzbd with Prowlarr";
      type = lib.types.bool;
      default = config.homelab.sabnzbd.enable && config.homelab.sonarr.enable;
      defaultText = lib.literalExpression "config.homelab.sabnzbd.enable && config.homelab.sonarr.enable";
    };
  };
  config = {
    setup-secrets.destinations = [
      {
        logPrefix = "SABnzbd integration keys";
        requires = [ "SABNZBD_API_KEY" ] ++ (catAttrs "authApiKeyVar" integrations);
        cmd = hllib.setup-secrets.mkScript pkgs ''
          setKubeSecret sabnzbd api-keys \
            SABNZBD_API_KEY "''${SABNZBD_API_KEY:?}" \
            ${lib.join " \\\n  " (
              map (key: ''${key} "''${${key}:?}"'') (catAttrs "authApiKeyVar" integrations)
            )}
        '';
      }
    ];
    kubetree.resources.sabnzbd = lib.mergeAttrsList (
      map (spec: {
        "${spec.name}-integration" = {
          apiVersion = "cluster.local";
          kind = "ScriptMacro";
          metadata.namespace = "sabnzbd";
          metadata.name = "integrate-${spec.name}";
          spec.allowEgress = [ spec.name ];
          spec.script = self.lib.integration.mkArrStackIntegrationScript spec;
          spec.podSpecMacro.mainContainer.envFrom = [ { secretRef.name = "api-keys"; } ];
        };
      }) integrations
    );
  };
}
