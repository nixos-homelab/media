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
  serviceUrl =
    { metadata, spec, ... }:
    "http://${metadata.name}.${
      lib.attrByPath [ "namespace" ] metadata.name metadata
    }:${builtins.toString spec.ingressPort}";
  prowlarrUrl = serviceUrl config.kubetree.resources.prowlarr.workload;
  capitalize =
    s: if s == "" then s else lib.toUpper (builtins.substring 0 1 s) + builtins.substring 1 (-1) s;
  appIntegrations =
    map
      (name: {
        inherit name;
        title = capitalize name;
        apiKeyVar = "${lib.toUpper name}_API_KEY";
        baseUrl = serviceUrl config.kubetree.resources.${name}.workload;
      })
      (
        filter (name: cfg.integrations.${name}.enable) [
          "sonarr"
          "radarr"
        ]
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
  };
  config = {
    setup-secrets.destinations = [
      {
        logPrefix = "Prowlarr integration keys";
        requires = [ "PROWLARR_API_KEY" ] ++ (catAttrs "apiKeyVar" appIntegrations);
        cmd = hllib.setup-secrets.mkScript pkgs ''
          setKubeSecret prowlarr api-keys \
            PROWLARR_API_KEY "''${PROWLARR_API_KEY:?}" \
            ${lib.join " \\\n  " (
              map (key: ''${key} "''${${key}:?}"'') (catAttrs "apiKeyVar" appIntegrations)
            )}
        '';
      }
    ];
    kubetree.resources.prowlarr = lib.mergeAttrsList (
      map (
        {
          name,
          title,
          apiKeyVar,
          baseUrl,
          ...
        }:
        {
          "${name}-integration" = {
            apiVersion = "cluster.local";
            kind = "ScriptMacro";
            metadata.namespace = "prowlarr";
            metadata.name = "integrate-${name}";
            spec.allowEgress = [
              "prowlarr"
              name
            ];
            spec.script = ''
              set -eo pipefail
              applications=$(curl -sfX GET '${prowlarrUrl}/api/v1/applications' \
                -H 'Content-Type: application/json' \
                -H "X-Api-Key: ''${PROWLARR_API_KEY:?}")
              if jq -re '.[] | select(.implementation == "${title}")' <<<"$applications" >/dev/null; then
                echo "${title} integration already set up" >&2
              else
                echo "Setting up ${title} integration" >&2
                if curl -sfX POST '${prowlarrUrl}/api/v1/applications' \
                  -H 'Content-Type: application/json' \
                  -H "X-Api-Key: ''${PROWLARR_API_KEY:?}" \
                  -d "$(jq -n --arg ${apiKeyVar} "''${${apiKeyVar}:?}" '${
                    builtins.toJSON {
                      enable = true;
                      name = "${title}";
                      syncLevel = "fullSync";
                      implementationName = "${title}";
                      implementation = "${title}";
                      configContract = "${title}Settings";
                      infoLink = "https://wiki.servarr.com/prowlarr/supported#${name}";
                      fields = lib.attrsToList { inherit prowlarrUrl baseUrl; };
                    }
                  } | .fields+=[{"name":"apiKey","value":''$${apiKeyVar}}]')"; then
                  echo "Successfully set up ${title} integration" >&2
                else
                  echo "${title} integration setup failed" >&2
                  exit 1
                fi
              fi
            '';
            spec.podSpecMacro.mainContainer.envFrom = [ { secretRef.name = "api-keys"; } ];
          };
        }
      ) appIntegrations
    );
  };
}
