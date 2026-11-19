# How FlareSolverr's logs are parsed: Python's logging with the format of flaresolverr.py, `ReqId <thread>` after the
# level at debug
{ inputs, ... }:
{
  lib,
  config,
  ...
}:
{
  imports = [ inputs.homelab-monitoring.nixosModules.alloy ];
  config = lib.mkIf config.homelab.flaresolverr.enable {
    homelab.alloy.logs = {
      formats.flaresolverr = {
        firstline = "^\\d{4}-\\d\\d-\\d\\d \\d\\d:\\d\\d:\\d\\d [A-Z]+ ";
        stages = ''
          stage.regex {
            expression = "^\\d{4}-\\d\\d-\\d\\d \\d\\d:\\d\\d:\\d\\d (?P<level>[A-Z]+) +(?:ReqId (?P<thread>\\d+) )?(?s)(?P<message>.*)$"
          }
        '';
      };
      pods.flaresolverr = {
        format = "flaresolverr";
        examples = [
          {
            lines = [
              "2026-11-19 07:12:03 INFO     Serving on http://0.0.0.0:8191"
              "2026-11-19 07:12:41 DEBUG    ReqId 140318 Waiting for title (attempt 1): Just a moment..."
            ];
            expect = [
              {
                message = "Serving on http://0.0.0.0:8191";
                level = "info";
              }
              {
                message = "Waiting for title (attempt 1): Just a moment...";
                level = "debug";
                fields.thread = "140318";
              }
            ];
          }
        ];
      };
    };
  };
}
