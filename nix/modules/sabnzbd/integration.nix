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
            fields = {
              host = "sabnzbd.sabnzbd";
              port = "8080";
            };
          };
        } spec
      )
      (
        lib.filterAttrs (name: _value: cfg.integrations.${name}.enable) {
          sonarr = {
            apiEndpoint = "http://sonarr.sonarr:8989/api/v3/downloadclient";
            settings = lib.recursiveUpdate {
              fields.tvCategory = "tv";
            } cfg.integrations.sonarr.settings;
          };
          radarr = {
            apiEndpoint = "http://radarr.radarr:7878/api/v3/downloadclient";
            settings = lib.recursiveUpdate {
              fields.movieCategory = "movies";
            } cfg.integrations.radarr.settings;
          };
          prowlarr = {
            apiEndpoint = "http://prowlarr.prowlarr:9696/api/v1/downloadclient";
            settings = lib.recursiveUpdate {
              fields.category = "prowlarr";
            } cfg.integrations.prowlarr.settings;
          };
        }
      );
  toApiKeyVar = name: "${lib.toUpper name}_API_KEY";
  # The field each app keeps its SABnzbd category in
  categoryFields = {
    sonarr = "tvCategory";
    radarr = "movieCategory";
    prowlarr = "category";
  };
in
{
  options.homelab.sabnzbd.integrations = {
    sonarr = {
      enable = lib.mkOption {
        description = "Whether to integrate SABNzbd with Sonarr";
        type = lib.types.bool;
        default = config.homelab.sabnzbd.enable && config.homelab.sonarr.enable;
        defaultText = lib.literalExpression "config.homelab.sabnzbd.enable && config.homelab.sonarr.enable";
      };
      settings = lib.mkOption {
        description = "Settings of the integration, the fields property will be converted from a attrSet to a name value pair array";
        type = lib.types.attrsOf lib.types.anything;
        default = { };
      };
    };
    radarr = {
      enable = lib.mkOption {
        description = "Whether to integrate SABNzbd with Radarr";
        type = lib.types.bool;
        default = config.homelab.sabnzbd.enable && config.homelab.radarr.enable;
        defaultText = lib.literalExpression "config.homelab.sabnzbd.enable && config.homelab.radarr.enable";
      };
      settings = lib.mkOption {
        description = "Settings of the integration, the fields property will be converted from a attrSet to a name value pair array";
        type = lib.types.attrsOf lib.types.anything;
        default = { };
      };
    };
    prowlarr = {
      enable = lib.mkOption {
        description = "Whether to integrate SABNzbd with Prowlarr";
        type = lib.types.bool;
        default = config.homelab.sabnzbd.enable && config.homelab.prowlarr.enable;
        defaultText = lib.literalExpression "config.homelab.sabnzbd.enable && config.homelab.prowlarr.enable";
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
      (hllib.setup-secrets.kubeSecretDestination pkgs {
        # As the manifests below: without an integration there is nothing to store
        enable = integrations != [ ];
        logPrefix = "SABnzbd integration keys";
        namespace = "sabnzbd";
        name = "api-keys";
        data = {
          SABNZBD_API_KEY = "SABNZBD_API_KEY";
        }
        // lib.genAttrs (catAttrs "authApiKeyVar" integrations) (key: key);
      })
    ];
    # In the manifest of sabnzbd, as before
    homelab.kubernetes = lib.mkIf (integrations != [ ]) {
      submodules.instances.sabnzbd.config.submodules.instances = lib.listToAttrs (
        map (
          spec:
          let
            category = spec.settings.fields.${categoryFields.${spec.name}};
          in
          {
            name = "integrate-${spec.name}";
            value = {
              submodule = "script";
              args = {
                # The client refuses a category SABnzbd doesn't have, and a new SABnzbd has none of these. set_config
                # creates it, or leaves an existing one as it is
                script = ''
                  curl -sf "http://sabnzbd.sabnzbd:8080/api?mode=set_config&section=categories&name=${category}&output=json&apikey=''${SABNZBD_API_KEY:?}" >/dev/null || {
                    echo "Creating the SABnzbd category ${category} failed" >&2
                    exit 1
                  }
                ''
                + self.lib.integration.mkArrStackIntegrationScript spec;
                allowEgress = [
                  spec.name
                  "sabnzbd"
                ];
                container.envFrom = [ { secretRef.name = "api-keys"; } ];
              };
            };
          }
        ) integrations
      );
    };
  };
}
