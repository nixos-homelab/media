# How rtorrent's exporter's logs are parsed; rtorrent and the SCGI bridge write plain lines
{ inputs, ... }:
{
  lib,
  config,
  ...
}:
{
  imports = [ inputs.homelab-monitoring.nixosModules.alloy ];
  config = lib.mkIf config.homelab.rtorrent.enable {
    homelab.alloy.logs.pods.rtorrent-exporter = {
      namespace = "rtorrent";
      format = "logfmt";
      examples = [
        {
          lines = [
            ''level=info ts=2026-11-18T07:22:07.646Z caller=main.go:38 msg="Starting rtorrent_exporter" version="(version=1.3.2, branch=, revision=unknown)"''
          ];
          expect = [
            {
              message = "Starting rtorrent_exporter";
              level = "info";
              fields.caller = "main.go:38";
            }
          ];
        }
      ];
    };
  };
}
