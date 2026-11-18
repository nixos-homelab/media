# How SABnzbd's logs are parsed: its log format (SABnzbd.py's logformat) and Python's tracebacks, which follow the line
# that logged them or open with "Exception ignored in" where nothing logged them
{ inputs, ... }:
{
  lib,
  config,
  ...
}:
{
  imports = [ inputs.homelab-monitoring.nixosModules.alloy ];
  config = lib.mkIf config.homelab.sabnzbd.enable {
    homelab.alloy.logs = {
      formats.sabnzbd = {
        firstline = "^(?:\\d{4}-\\d\\d-\\d\\d \\d\\d:\\d\\d:\\d\\d,\\d+::|Exception ignored in)";
        stages = ''
          stage.regex {
            expression = "^\\d{4}-\\d\\d-\\d\\d \\d\\d:\\d\\d:\\d\\d,\\d+::(?P<level>[A-Z]+)::\\[(?P<caller>[^\\]]+)\\] (?s)(?P<message>.*)$"
          }
          stage.regex {
            expression = "^(?P<message>(?P<level>Exception) ignored in(?s:.*))$"
          }
        '';
        levels.error = [ "exception" ];
      };
      pods.sabnzbd = {
        format = "sabnzbd";
        examples = [
          {
            lines = [
              "2026-11-18 07:20:11,123::INFO::[downloader:301] Downloader-thread started"
              "Exception ignored in: <function IOBase.__del__ at 0x7321d311d6c0>"
              "Traceback (most recent call last):"
              ''File "/nix/store/x-python3-3.13.18-env/lib/python3.13/site-packages/cheroot/makefile.py", line 32, in _flush_unlocked''
              "    return self._sock.send(b)"
              "OSError: [Errno 9] Bad file descriptor"
            ];
            expect = [
              {
                message = "Downloader-thread started";
                level = "info";
                fields.caller = "downloader:301";
              }
              {
                message = lib.concatStringsSep "\n" [
                  "Exception ignored in: <function IOBase.__del__ at 0x7321d311d6c0>"
                  "Traceback (most recent call last):"
                  ''File "/nix/store/x-python3-3.13.18-env/lib/python3.13/site-packages/cheroot/makefile.py", line 32, in _flush_unlocked''
                  "    return self._sock.send(b)"
                  "OSError: [Errno 9] Bad file descriptor"
                ];
                level = "error";
              }
            ];
          }
        ];
      };
    };
  };
}
