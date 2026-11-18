# How the Plex exporter's logs are parsed; Plex itself writes to files under its data directory, not to stdout
{ inputs, ... }:
{
  lib,
  config,
  ...
}:
{
  imports = [ inputs.homelab-monitoring.nixosModules.alloy ];
  config = lib.mkIf config.homelab.plex.enable {
    # logfmt, and bare lines of their own in between: no multiline records
    homelab.alloy.logs.formats.plex-exporter = {
      inherit (config.homelab.alloy.logs.formats.logfmt) stages fields;
    };
    homelab.alloy.logs.pods.plex-exporter = {
      namespace = "plex";
      format = "plex-exporter";
      examples = [
        {
          lines = [
            ''level=info msg="Received PlaySessionStateNotification" SessionKey=2 userName=andsens userID=1 state=playing''
            "unknown websocket event name: transcodeSession.start"
          ];
          expect = [
            {
              message = "Received PlaySessionStateNotification";
              level = "info";
            }
            {
              message = "unknown websocket event name: transcodeSession.start";
              level = "info";
            }
          ];
        }
      ];
    };
  };
}
