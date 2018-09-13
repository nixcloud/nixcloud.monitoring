{ lib, config } :
with lib;
let
  stdOptions = (import ./lib/stdOptions.nix) {inherit lib; inherit config;};
in
 {
   check_ssh = mkOption {
    default = [];
    type = types.listOf (types.submodule ({ config, options, lib } : 
      {
        options = {
          port = mkOption {
            type = types.int;
            default = 22;
            description = "Port number (default: 22)";
          };
          remoteVersion = mkOption {
            type = types.str;
            example = "OpenSSH_3.9p1";
            default = "";
            description = "Alert if string doesn't match expected server version (ex: OpenSSH_3.9p1)";
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
                cmd = [ "/opt/bin/check_ssh" ];
                host = [ "-H" "${toString config.host}" ];
                ipv = if (config.ipv4) then [ "-4" ] else [ "-6" ];
                port = [ "-p" "${toString config.port}" ];
                timeout = [ "-t" "${toString config.timeout}" ];
                remoteVersion = if (config.remoteVersion == "") then [] else [ "-r" "${config.remoteVersion}" ];
                args = cmd ++ host ++ port ++ ipv ++ timeout ++ remoteVersion;
                command_line = escapeShellArgs args;
              in
                {
                  command_name = "check_ssh-${builtins.hashString "sha256" command_line}";
                  inherit command_line;
                };
          }; 
        } // stdOptions // { name = stdOptions.name "SSH";};
    }));
  };
}
