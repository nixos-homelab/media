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
  mkArrStackIntegrationScript =
    {
      name,
      apiEndpoint,
      authApiKeyVar,
      settings,
      apiKeyFieldName ? null,
      apiKeyVar ? null,
    }:
    let
      title = capitalize name;
    in
    ''
      set -eo pipefail
      data=$(curl -sfX GET '${apiEndpoint}' \
        -H 'Content-Type: application/json' \
        -H "X-Api-Key: ''${${authApiKeyVar}:?}")
      if jq -re '.[] | select(.implementation == "${settings.implementation}")' <<<"$data" >/dev/null; then
        echo "${title} integration already set up" >&2
      else
        echo "Setting up ${title} integration" >&2
        payload='${builtins.toJSON (settings // { fields = lib.attrsToList settings.fields; })}'
        ${lib.optionalString (apiKeyVar != null) ''
          payload=$(jq --arg ${apiKeyVar} "''${${apiKeyVar}:?}" '.fields+=[{"name":"${apiKeyFieldName}","value":''$${apiKeyVar}}]' <<<"$payload")
        ''}
        if curl -sfX POST '${apiEndpoint}' \
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
}
