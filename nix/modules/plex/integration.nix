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
        lib.filterAttrs (name: _value: cfg.integrations.${name}.enable) {
          # Imports and upgrades add to the library; renames and deletes change it
          sonarr.settings = lib.recursiveUpdate {
            onUpgrade = true;
            onImportComplete = true;
            onRename = true;
            onEpisodeFileDelete = true;
            onSeriesDelete = true;
          } cfg.integrations.sonarr.settings;
          radarr.settings = lib.recursiveUpdate {
            onDownload = true;
            onUpgrade = true;
            onRename = true;
            onMovieFileDelete = true;
            onMovieDelete = true;
          } cfg.integrations.radarr.settings;
        }
      );
  toApiKeyVar = name: "${lib.toUpper name}_API_KEY";
  serviceUrls = {
    sonarr = "http://sonarr.sonarr:8989";
    radarr = "http://radarr.radarr:7878";
  };
  # The library sections: the root folders of the app that lie in a volume of Plex, where it sees them at the same path
  inPlexVolume =
    path:
    lib.any (mount: lib.hasPrefix "${lib.removeSuffix "/" mount}/" "${path}/") (attrNames cfg.volumes);
  libraries = lib.mapAttrs (
    name: spec:
    let
      rootFolders = config.homelab.${name}.rootFolders;
      locations = filter inPlexVolume rootFolders;
    in
    {
      inherit (spec) name language;
      inherit locations;
      enable = cfg.integrations.${name}.enable && spec.enable && locations != [ ];
      outside = lib.filter (path: !inPlexVolume path) rootFolders;
    }
    // (
      {
        sonarr = {
          type = "show";
          agent = "tv.plex.agents.series";
          scanner = "Plex TV Series";
        };
        radarr = {
          type = "movie";
          agent = "tv.plex.agents.movie";
          scanner = "Plex Movie";
        };
      }
      .${name}
    )
  ) (lib.mapAttrs (_: i: i.library) cfg.integrations);
  # Creates the section unless one has any of its folders already. Never changes or removes a section
  librarySetup =
    library:
    let
      query = lib.join "&" (
        [
          "name=${lib.escapeURL library.name}"
          "type=${library.type}"
          "agent=${library.agent}"
          "scanner=${lib.escapeURL library.scanner}"
          "language=${library.language}"
        ]
        ++ map (path: "location=${lib.escapeURL path}") library.locations
      );
    in
    ''
      plex() {
        local method=$1 path=$2
        curl --insecure -sfX "$method" "https://plex.plex:32400$path" \
          -H 'Accept: application/json' \
          -H "X-Plex-Token: ''${PLEX_API_KEY:?}"
      }
      sections=$(plex GET /library/sections)
      present=$(jq -r --argjson wanted ${lib.escapeShellArg (toJSON library.locations)} \
        '[.MediaContainer.Directory[]?.Location[]?.path | rtrimstr("/")] as $have
          | $wanted[] | select(rtrimstr("/") as $p | $have | index($p))' <<<"$sections")
      if [[ -n $present ]]; then
        echo "Plex has a library section with $present already, leaving the sections as they are" >&2
      else
        plex POST ${lib.escapeShellArg "/library/sections?${query}"} >/dev/null
        echo "Created the Plex library section ${library.name}" >&2
      fi
    '';
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
      library = {
        enable = lib.mkOption {
          description = ''
            Whether to create a library section for the root folders of Sonarr (`homelab.sonarr.rootFolders`) that lie
            in a volume of Plex. It is created only while no section has any of them; sections are never changed or
            removed.
          '';
          type = lib.types.bool;
          default = true;
        };
        name = lib.mkOption {
          description = "Name of the library section.";
          type = lib.types.str;
          default = "TV Shows";
        };
        language = lib.mkOption {
          description = "Language of the library section, as a code like `en-US`.";
          type = lib.types.str;
          default = "en-US";
        };
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
      library = {
        enable = lib.mkOption {
          description = ''
            Whether to create a library section for the root folders of Radarr (`homelab.radarr.rootFolders`) that lie
            in a volume of Plex. It is created only while no section has any of them; sections are never changed or
            removed.
          '';
          type = lib.types.bool;
          default = true;
        };
        name = lib.mkOption {
          description = "Name of the library section.";
          type = lib.types.str;
          default = "Movies";
        };
        language = lib.mkOption {
          description = "Language of the library section, as a code like `en-US`.";
          type = lib.types.str;
          default = "en-US";
        };
      };
      settings = lib.mkOption {
        description = "Settings of the integration, the fields property will be converted from a attrSet to a name value pair array";
        type = lib.types.attrsOf lib.types.anything;
        default = { };
      };
    };

  };
  config = {
    warnings = lib.concatLists (
      lib.mapAttrsToList (
        name: library:
        lib.optional (cfg.integrations.${name}.enable && library.outside != [ ])
          "homelab.plex: no volume of Plex holds the ${name} root folders ${toString library.outside}, so its library section leaves them out"
      ) libraries
    );
    setup-secrets.destinations = [
      (hllib.setup-secrets.kubeSecretDestination pkgs {
        # As the manifests below: without an integration there is nothing to store
        enable = integrations != [ ];
        logPrefix = "Plex integration keys";
        namespace = "plex";
        name = "api-keys";
        data = {
          PLEX_API_KEY = "PLEX_API_KEY";
        }
        // lib.genAttrs (catAttrs "authApiKeyVar" integrations) (key: key);
      })
    ];
    # In the manifest of plex, as before
    homelab.kubernetes = lib.mkIf (integrations != [ ]) {
      submodules.instances.plex.config.submodules.instances = lib.listToAttrs (
        map (spec: {
          name = "integrate-${spec.name}";
          value = {
            submodule = "script";
            args = {
              script =
                self.lib.integration.mkArrStackIntegrationScript spec
                + lib.optionalString libraries.${spec.name}.enable (librarySetup libraries.${spec.name});
              allowEgress = [
                spec.name
                "plex"
              ];
              container.envFrom = [ { secretRef.name = "api-keys"; } ];
            };
          };
        }) integrations
      );
    };
  };
}
