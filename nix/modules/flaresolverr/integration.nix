# FlareSolverr as an indexer proxy of Prowlarr. Prowlarr sends an indexer through a proxy when they share a tag, so the
# job gives the proxy a tag; an indexer behind Cloudflare gets it in the UI
{ inputs, ... }:
{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.homelab.flaresolverr.integrations.prowlarr;
  hllib = inputs.homelab-shared.lib;
  payload = {
    name = "FlareSolverr";
    implementation = "FlareSolverr";
    configContract = "FlareSolverrSettings";
    fields = [
      {
        name = "host";
        value = "http://flaresolverr.flaresolverr:8191/";
      }
      {
        name = "requestTimeout";
        value = cfg.requestTimeout;
      }
    ];
  };
  script = ''
    set -eo pipefail
    api() {
      local method=$1 path=$2
      shift 2
      curl -sSX "$method" --fail-with-body "http://prowlarr.prowlarr:9696/api/v1/$path" \
        -H 'Content-Type: application/json' \
        -H "X-Api-Key: ''${PROWLARR_API_KEY:?}" "$@"
    }
    # Prowlarr tests the proxy as it saves it, so FlareSolverr has to answer first. It starts Chromium before it serves
    for _ in $(seq 60); do
      curl -sf http://flaresolverr.flaresolverr:8191/health >/dev/null && break
      sleep 5
    done
    if ! tag=$(api GET tag | jq -re --arg label ${lib.escapeShellArg cfg.tag} '.[] | select(.label == $label) | .id'); then
      tag=$(api POST tag -d "$(jq -n --arg label ${lib.escapeShellArg cfg.tag} '{label: $label}')" | jq -re .id)
      echo "Created the Prowlarr tag ${cfg.tag}" >&2
    fi
    payload=${lib.escapeShellArg (builtins.toJSON payload)}
    proxies=$(api GET indexerproxy)
    if id=$(jq -re '.[] | select(.implementation == "FlareSolverr") | .id' <<<"$proxies"); then
      # The tags given in the UI stay
      payload=$(jq --argjson tag "$tag" --argjson current "$(jq --argjson id "$id" '.[] | select(.id == $id)' <<<"$proxies")" \
        '. + {id: $current.id, tags: ($current.tags + [$tag] | unique)}' <<<"$payload")
      api PUT "indexerproxy/$id" -d "$payload" >/dev/null
      echo "Updated the FlareSolverr proxy of Prowlarr" >&2
    else
      api POST indexerproxy -d "$(jq --argjson tag "$tag" '. + {tags: [$tag]}' <<<"$payload")" >/dev/null
      echo "Set up the FlareSolverr proxy of Prowlarr" >&2
    fi
  '';
in
{
  options.homelab.flaresolverr.integrations.prowlarr = {
    enable = lib.mkOption {
      description = "Whether to add FlareSolverr to Prowlarr as an indexer proxy";
      type = lib.types.bool;
      default = config.homelab.flaresolverr.enable && config.homelab.prowlarr.enable;
      defaultText = lib.literalExpression "config.homelab.flaresolverr.enable && config.homelab.prowlarr.enable";
    };
    tag = lib.mkOption {
      description = "The Prowlarr tag of the proxy: indexers with it go through FlareSolverr";
      type = lib.types.str;
      default = "flaresolverr";
    };
    requestTimeout = lib.mkOption {
      description = "How long FlareSolverr may take to solve a challenge, in seconds";
      type = lib.types.ints.positive;
      default = 60;
    };
  };
  config = lib.mkIf cfg.enable {
    setup-secrets.destinations = [
      {
        logPrefix = "FlareSolverr integration key";
        requires = [ "PROWLARR_API_KEY" ];
        cmd = hllib.setup-secrets.mkScript pkgs ''
          setKubeSecret flaresolverr api-keys \
            PROWLARR_API_KEY "''${PROWLARR_API_KEY:?}"
        '';
      }
    ];
    homelab.kubernetes.submodules.instances.flaresolverr.config.submodules.instances.integrate-prowlarr =
      {
        submodule = "script";
        args = {
          inherit script;
          allowEgress = [
            "prowlarr"
            "flaresolverr"
          ];
          container.envFrom = [ { secretRef.name = "api-keys"; } ];
        };
      };
  };
}
