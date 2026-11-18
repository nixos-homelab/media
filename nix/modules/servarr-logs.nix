# The log format of Sonarr, Radarr and Prowlarr (NLog on stdout): `[Level] Component: message`, an exception's lines
# after it. Imported by each of their logs.nix; the key keeps it to one definition
{ inputs, ... }:
{ ... }:
{
  key = "${toString __curPos.file}#modules.nixos.servarr-logs";
  imports = [ inputs.homelab-monitoring.nixosModules.alloy ];
  config.homelab.alloy.logs.formats.servarr = {
    firstline = "^\\[(?:Trace|Debug|Info|Warn|Error|Fatal)\\] ";
    stages = ''
      stage.regex {
        expression = "^\\[(?P<level>[A-Za-z]+)\\] (?P<component>[\\w.]+): (?s)(?P<message>.*)$"
      }
    '';
  };
}
