# integration 


## `lib.integration.capitalize` 

Uppercase the first character of `s`, leaving the rest unchanged. An
empty string is returned as-is.

### Arguments

`s` (`String`): The string to capitalize

### Example

```nix
capitalize "sonarr"
=> "Sonarr"
```

## `lib.integration.workloadServiceHostPort` 

Get the in-cluster hostname and port for a `WorkloadMacro` resource's
Kubernetes Service, as `{ host; port; }`. The host is the
`<name>.<namespace>` short form that's resolvable cluster-internally
without the full `.svc.cluster.local` suffix; `namespace` falls back to
`metadata.name` if `metadata.namespace` isn't set.

### Arguments

`workload`: A resource with `metadata.name` and `spec.ingressPort` (an
`apiVersion = "cluster.local"; kind = "WorkloadMacro";` resource, as
found at `config.kubetree.resources.<name>.<item>`)

### Example

```nix
workloadServiceHostPort {
  metadata = { name = "sonarr"; namespace = "media"; };
  spec.ingressPort = 8989;
}
=> { host = "sonarr.media"; port = "8989"; }
```

## `lib.integration.workloadServiceUrl` 

Get the in-cluster `http://` URL for a `WorkloadMacro` resource's
Kubernetes Service.

### Arguments

`workload`: A resource with `metadata.name` and `spec.ingressPort` (see
[`workloadServiceHostPort`](#libintegrationworkloadservicehostport))

### Example

```nix
workloadServiceUrl {
  metadata = { name = "sonarr"; namespace = "media"; };
  spec.ingressPort = 8989;
}
=> "http://sonarr.media:8989"
```

## `lib.integration.mkArrStackIntegrationScript` 

Build a shell script that idempotently registers an integration with
an *Arr-stack app's (Sonarr/Radarr/Prowlarr-style) REST API: it checks
`apiEndpoint` for an existing entry matching
`settings.implementation`, and if none is found, `POST`s `settings` to
create one.

### Arguments

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

### Example

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


