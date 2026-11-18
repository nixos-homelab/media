# How the integration jobs' output is parsed: a line of text, then the API's pretty-printed JSON answer, one record.
# Imported by the modules with an integration.nix; the key keeps it to one definition
{ inputs, ... }:
{ lib, config, ... }:
{
  key = "${toString __curPos.file}#modules.nixos.integration-logs";
  imports = [ inputs.homelab-monitoring.nixosModules.alloy ];
  config.homelab.alloy.logs = {
    formats.integration = {
      firstline = "^[A-Za-z]";
      stages = config.homelab.alloy.logs.formats.plain.stages;
    };
    pods.integrations = {
      namespace = null;
      containerPattern = "integrate-.+";
      format = "integration";
      examples = [
        {
          labels = {
            namespace = "flood";
            container = "integrate-radarr";
          };
          lines = [
            "Radarr integration already set up, updating settings"
            "{"
            ''"enable": true,''
            ''"privacy": "normal"''
            "}"
          ];
          expect = [
            {
              message = lib.concatStringsSep "\n" [
                "Radarr integration already set up, updating settings"
                "{"
                ''"enable": true,''
                ''"privacy": "normal"''
                "}"
              ];
              level = "unknown";
              program = "integrate-radarr";
            }
          ];
        }
      ];
    };
  };
}
