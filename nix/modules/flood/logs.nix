# How Flood's logs are parsed: pino's JSON, and morgan's coloured request lines with the status as their level
{ inputs, ... }:
{
  lib,
  config,
  ...
}:
let
  logs = config.homelab.alloy.logs;
  esc = builtins.fromJSON ''"\u001b"'';
in
{
  imports = [ inputs.homelab-monitoring.nixosModules.alloy ];
  config = lib.mkIf config.homelab.flood.enable {
    homelab.alloy.logs = {
      formats.flood = {
        decolorize = true;
        inherit (logs.formats.json) fields levels;
        stages = logs.formats.json.stages + ''
          stage.regex {
            expression = "^(?P<message>(?P<method>[A-Z]+) (?P<path>\\S+) (?P<status>\\d{3}) (?P<duration>[\\d.]+ ms) - \\S+)$"
          }
          // morgan writes no level: the status stands in for it
          stage.template {
            source   = "level"
            template = "{{ with index . \"level\" }}{{ . }}{{ else }}{{ with index . \"status\" }}{{ if hasPrefix \"5\" . }}error{{ else if hasPrefix \"4\" . }}warning{{ else }}info{{ end }}{{ end }}{{ end }}"
          }
        '';
      };
      pods.flood = {
        format = "flood";
        examples = [
          {
            lines = [
              ''{"level":30,"time":"2026-11-18T17:22:40.221Z","pid":7,"hostname":"flood-74886977b5-pr28z","name":"flood:web-server","reqId":"req-697","res":{"statusCode":200},"responseTime":0.22381199896335602,"msg":"request completed"}''
              "${esc}[0mGET / ${esc}[32m200${esc}[0m 0.060 ms - 873${esc}[0m\n"
              "${esc}[0mGET /api/torrents ${esc}[33m404${esc}[0m 1.204 ms - 9${esc}[0m\n"
              ''{"level":50,"time":"2026-11-18T17:30:00.000Z","pid":7,"name":"flood:service","msg":"Failed to fetch torrent list."}''
            ];
            expect = [
              {
                message = "request completed";
                level = "info";
                fields = {
                  component = "flood:web-server";
                  request_id = "req-697";
                  pid = "7";
                };
              }
              {
                message = "GET / 200 0.060 ms - 873";
                level = "info";
                fields = {
                  method = "GET";
                  path = "/";
                  status = "200";
                  duration = "0.060 ms";
                };
              }
              {
                message = "GET /api/torrents 404 1.204 ms - 9";
                level = "warning";
              }
              {
                message = "Failed to fetch torrent list.";
                level = "error";
              }
            ];
          }
        ];
      };
    };
  };
}
