# How Flood's logs are parsed: pino's JSON, and morgan's coloured request lines
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
        '';
      };
      pods.flood = {
        format = "flood";
        examples = [
          {
            lines = [
              ''{"level":30,"time":"2026-11-18T17:22:40.221Z","pid":7,"hostname":"flood-74886977b5-pr28z","name":"flood:web-server","reqId":"req-697","res":{"statusCode":200},"responseTime":0.22381199896335602,"msg":"request completed"}''
              "${esc}[0mGET / ${esc}[32m200${esc}[0m 0.060 ms - 873${esc}[0m"
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
                level = "unknown";
                fields = {
                  method = "GET";
                  path = "/";
                  status = "200";
                  duration = "0.060 ms";
                };
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
