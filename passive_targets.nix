{ config, lib } :
with lib;
let
  stdOptions = (import ./active/lib/stdOptions.nix) {inherit lib; inherit config;};
in

mkOption {
  description = ''A list of passive monitoring targets. They can either be `imperative` or `declarative`.'';
  # the default value is for status.nixcloud.io so we have at least one element if the configuration is empty
  default = [
    {
      host = "passive.io";
      name = "HTTP";
      public = false;
    }
  ];
  type = types.listOf (types.submodule {
    options = {
      tags = stdOptions.tags;
      host = stdOptions.host;
      public = stdOptions.public;
      name = mkOption {
        type = types.str;
        description = ''
          Service name shown in the status.nixcloud.io monitoring frontend. The string "`host`-`name`" must be globally unique taken all the passive and active targets together.
        '';
      };
      script = mkOption {
        description = ''
          A bash script snippet which defines these variables:

          * `exit`: Exit code 0 [OK], 1 [WARNING], 2 [CRITICAL], 3 [UNKNOWN]
          * `status`: A text based string without new lines used as program status statement.
          * `perfdata`: JSON structure which can later be converted into a grafana graph or saved into a database.

          If this `script` is used, systemd will periodically run it and upload the result automatically (declarative usage) but if it is left empty one has to call the upload script manually (imperative usage).
        '';
        type = types.lines;
        example = ''
          status = /bin/mybackupScript
          exit=$? 
          perfdata = '{"x":5,"y":6}';
        '';
        default = "";
      };
      timers = mkOption {
        options = {
          check = mkOption {
            default = 60;
            description = "Interval, in minutes, how often the passive check result should be pushed from the nixcloud.monitoring client to the server.";
          };
          timeout = mkOption {
            default = 180;
            description = "Interval, in minutes, when a missing service upload should trigger a failure. This should be at least a factor of two or more of the check time interval.";
          };
        };
      };
    };
  });
}
