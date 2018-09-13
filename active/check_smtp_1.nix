{ lib, config } :
with lib;
let
  stdOptions = (import ./lib/stdOptions.nix) {inherit lib; inherit config;};
in
 {
   check_smtp = mkOption {
    default = [];
    type = types.listOf (types.submodule ({ config, options, lib } : 
      {
        options = {
          port = mkOption {
            type = types.int;
            default = 25;
            description = "TCP Port number";
          };
          certificate = mkOption {
            type = types.int;
            example = 10;
            default = 1000;
            description = "Minimum number of days a certificate has to be valid.";
          };
          starttls = mkOption {
            type = types.bool;
            default = false;
            description = "Use STARTTLS for the connection.";
          };
          timeout = mkOption {
            type = types.int;
            default = 10;
            description = "Seconds before connection times out";
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
                cmd = [ "/opt/bin/check_smtp" ];
                host = [ "-H" "${toString config.host}" ];
                ipv = if (config.ipv4) then [ "-4" ] else [ "-6" ];
                port = [ "-p" "${toString config.port}" ];
                certificate = if (config.certificate == 1000) then [] else [ "-D" "${toString config.certificate}" ];
                starttls = if (config.starttls) then [ "-S" ] else [];
                timeout = [ "-t" "${toString config.timeout}" ];
                args = cmd ++ host ++ ipv ++ certificate ++ starttls ++ timeout;
                command_line = escapeShellArgs args;
              in
                {
                  command_name = "check_smtp-${builtins.hashString "sha256" command_line}";
                  inherit command_line;
                };
          }; 
        } // stdOptions // { name = stdOptions.name "SMTP";};
    }));
  };
}
