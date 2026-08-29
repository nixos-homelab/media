{ lib, ... }:
with builtins;
rec {
  /**
    Uppercase the first character of `s`, leaving the rest unchanged. An
    empty string is returned as-is.

    # Arguments

    `s` (`String`): The string to capitalize

    # Example

    ```nix
    capitalize "sonarr"
    => "Sonarr"
    ```
  */
  capitalize = s: if s == "" then s else lib.toUpper (substring 0 1 s) + substring 1 (-1) s;
  /**
    Build a shell script that idempotently registers an integration with
    an *Arr-stack app's (Sonarr/Radarr/Prowlarr-style) REST API: it checks
    `apiEndpoint` for an existing entry matching
    `settings.implementation`, and if none is found, `POST`s `settings` to
    create one.

    # Arguments

    `name` (`String`): Name of the app being integrated with, used in log
    messages

    `apiEndpoint` (`String`): URL of the integration list/create endpoint

    `authApiKeyVar` (`String`): Environment variable holding the API key
    for `apiEndpoint`

    `settings` (`AttrSet`): The integration payload to `POST`;
    `settings.fields` is an attrset serialized to the API's field-list
    format, and `settings.implementation` identifies the integration type

    `apiKeyFieldName` (`String`): Field name to inject `apiKeyVar`'s value
    under in `settings.fields` (*optional*, required if `apiKeyVar` is set)

    `apiKeyVar` (`String`): Environment variable to inject into
    `settings.fields` (*optional*)

    # Example

    ```nix
    integration.mkArrStackIntegrationScript {
      name = "Sonarr";
      apiEndpoint = "${integration.workloadServiceUrl prowlarrWorkload}/api/v1/applications";
      authApiKeyVar = "PROWLARR_API_KEY";
      apiKeyFieldName = "apiKey";
      apiKeyVar = "SONARR_API_KEY";
      settings = {
        implementation = "Sonarr";
        fields.baseUrl = integration.workloadServiceUrl sonarrWorkload;
      };
    }
    ```
  */
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
      payload='${builtins.toJSON (settings // { fields = lib.attrsToList settings.fields; })}'
      ${lib.optionalString (apiKeyVar != null) ''
        payload=$(jq --arg ${apiKeyVar} "''${${apiKeyVar}:?}" '.fields+=[{"name":"${apiKeyFieldName}","value":''$${apiKeyVar}}]' <<<"$payload")
      ''}
      if id=$(jq -re '.[] | select(.implementation == "${settings.implementation}") | .id' <<<"$data"); then
        echo "${title} integration already set up, updating settings" >&2
        if curl -sfX PUT "${apiEndpoint}/$id" \
          -H 'Content-Type: application/json' \
          -H "X-Api-Key: ''${${authApiKeyVar}:?}" \
          -d "$payload"; then
          echo "Successfully updated ${title} integration" >&2
        else
          echo "${title} integration update failed" >&2
          exit 1
        fi
      else
        echo "Setting up ${title} integration" >&2
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
