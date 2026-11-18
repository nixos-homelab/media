# How Sonarr's logs are parsed
{ self, ... }:
{
  lib,
  config,
  ...
}:
{
  imports = self.lib.importsApply [ ../servarr-logs.nix ];
  config = lib.mkIf config.homelab.sonarr.enable {
    homelab.alloy.logs.pods.sonarr = {
      format = "servarr";
      examples = [
        {
          lines = [ "[Info] DiskScanService: Completed scanning disk for Secret Level " ];
          expect = [
            {
              message = "Completed scanning disk for Secret Level";
              level = "info";
              fields.component = "DiskScanService";
            }
          ];
        }
      ];
    };
  };
}
