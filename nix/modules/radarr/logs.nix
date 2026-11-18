# How Radarr's logs are parsed
{ self, ... }:
{
  lib,
  config,
  ...
}:
{
  imports = self.lib.importsApply [ ../servarr-logs.nix ];
  config = lib.mkIf config.homelab.radarr.enable {
    homelab.alloy.logs.pods.radarr = {
      format = "servarr";
      examples = [
        {
          lines = [
            "[Warn] DownloadMonitoringService: Unable to retrieve queue and history items from Flood "
            ""
            "[v6.4.4.10685] NzbDrone.Core.Download.Clients.DownloadClientException: Unable to connect to Flood, please check your settings"
            "   at NzbDrone.Core.Download.Clients.Flood.FloodProxy.HandleRequest(HttpRequest request, FloodSettings settings) in ./NzbDrone.Core/Download/Clients/Flood/FloodProxy.cs:line 77"
            "   at NzbDrone.Core.Download.Clients.Flood.Flood.GetItems() in ./NzbDrone.Core/Download/Clients/Flood/Flood.cs:line 108"
            ""
            ""
            "[Info] IMDbListImport: IMDb List ur8812996: Importing movies "
          ];
          expect = [
            {
              message = lib.concatStringsSep "\n" [
                "Unable to retrieve queue and history items from Flood "
                ""
                "[v6.4.4.10685] NzbDrone.Core.Download.Clients.DownloadClientException: Unable to connect to Flood, please check your settings"
                "   at NzbDrone.Core.Download.Clients.Flood.FloodProxy.HandleRequest(HttpRequest request, FloodSettings settings) in ./NzbDrone.Core/Download/Clients/Flood/FloodProxy.cs:line 77"
                "   at NzbDrone.Core.Download.Clients.Flood.Flood.GetItems() in ./NzbDrone.Core/Download/Clients/Flood/Flood.cs:line 108"
              ];
              level = "warning";
              fields.component = "DownloadMonitoringService";
            }
            {
              message = "IMDb List ur8812996: Importing movies";
              level = "info";
              fields.component = "IMDbListImport";
            }
          ];
        }
      ];
    };
  };
}
