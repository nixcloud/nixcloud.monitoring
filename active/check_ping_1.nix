{ lib, config } :
with lib;
let
  stdOptions = (import ./lib/stdOptions.nix) {inherit lib; inherit config;};
in
 {
   check_ping = mkOption {
    default = [];
    type = types.listOf (types.submodule ({ config, options, lib } : 
      {
        options = {
          warning = mkOption {
            type = types.str;
            default = "10,2%";
            description = ''
              THRESHOLD is <rta>,<pl>% where <rta> is the round trip average travel
              time (ms) which triggers a WARNING or CRITICAL state, and <pl> is the
              percentage of packet loss to trigger an alarm state.
            '';
          };
          critical = mkOption {
            type = types.str;
            default = "20,5%";
            description = ''
              THRESHOLD is <rta>,<pl>% where <rta> is the round trip average travel
              time (ms) which triggers a WARNING or CRITICAL state, and <pl> is the
              percentage of packet loss to trigger an alarm state.
            '';
          };
          timeout = mkOption {
            type = types.int;
            default = 10;
            description = "Seconds before connection times out (default: 10)";
          };
          generate = mkOption {
            readOnly = true;
            internal = true;
            type = with types; submodule {
              options = {
                command_name = mkOption {
                  type = types.str;
                };
                command_line = mkOption {
                  type = types.str;                
                };
              };
            };
            default = 
              let
                cmd = [ "/opt/bin/check_ping" ];
                host = [ "-H" "${toString config.host}" ];
                ipv = if (config.ipv4) then [ "-4" ] else [ "-6" ];
                warning = [ "-w" "${config.warning}" ];
                critical = [ "-w" "${config.critical}" ];
                timeout = [ "-t" "${toString config.timeout}" ];
                args = cmd ++ host ++ ipv ++ warning ++ critical ++ timeout;
                command_line = escapeShellArgs args;
              in
                {
                  command_name = "check_ping-${builtins.hashString "sha256" command_line}";
                  inherit command_line;
                };
          }; 
        } // stdOptions // { name = stdOptions.name "PING";};
    }));
  };
}
