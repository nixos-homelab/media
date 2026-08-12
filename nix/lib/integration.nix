{ lib, ... }:
with builtins;
rec {
  capitalize = s: if s == "" then s else lib.toUpper (substring 0 1 s) + substring 1 (-1) s;
  workloadServiceHostPort = { metadata, spec, ... }: {
    host = "${metadata.name}.${lib.attrByPath [ "namespace" ] metadata.name metadata}";
    port = toString spec.ingressPort;
  };
  workloadServiceUrl =
    workload:
    let
      hostPort = workloadServiceHostPort workload;
    in
    "http://${hostPort.host}:${hostPort.port}";
  mkIntegrationJob =
    spec:
    let
      inherit (spec)
        apiType
        name
        title
        apiUrl
        authApiKeyVar
        hasApiKey
        extraSettings
        ;
    in
    {
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
        data=$(curl -sfX GET '${apiUrl}/api/v1/${apiType}' \
          -H 'Content-Type: application/json' \
          -H "X-Api-Key: ''${${authApiKeyVar}:?}")
        if jq -re '.[] | select(.implementation == "${title}")' <<<"$data" >/dev/null; then
          echo "${title} integration already set up" >&2
        else
          echo "Setting up ${title} integration" >&2
          payload='${
            let
              payload = lib.recursiveUpdate {
                enable = true;
                name = "${title}";
                implementationName = "${title}";
                implementation = "${title}";
                configContract = "${title}Settings";
              } extraSettings;
            in
            builtins.toJSON (payload // { fields = lib.attrsToList payload.fields; })
          }'
          ${lib.optionalString hasApiKey ''
            payload=$(jq --arg ${spec.apiKeyVar} "''${${spec.apiKeyVar}:?}" '.fields+=[{"name":"apiKey","value":''$${spec.apiKeyVar}}]' <<<"$payload")
          ''}
          if curl -sfX POST '${apiUrl}/api/v1/${apiType}' \
            -H 'Content-Type: application/json' \
            -H "X-Api-Key: ''${${authApiKeyVar}:?}" \
            -d "$payload"; then
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
