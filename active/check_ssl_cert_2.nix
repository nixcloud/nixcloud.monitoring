{ lib, config } :
with lib;
let
  stdOptions = (import ./lib/stdOptions.nix) {inherit lib; inherit config;};
in
 {
   check_ssl_cert = mkOption {
    default = [];
    type = types.listOf (types.submodule ({ config, options, lib } : 
      {
        options = {
          port = mkOption {
            type = types.int;
            default = 443;
            description = "TCP Port number";
          };
          warningDays = mkOption {
            type = types.int;
            example = 10;
            default = 1000;
            description = "Minimum number of days a certificate has to be valid to issue a warning status";
          };
          timeout = mkOption {
            type = types.int;
            default = 15;
            description = "Seconds before connection times out (default: 15)";
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
                cmd = [ "/opt/bin/check_ssl_cert" ];
                host = [ "-H" "${toString config.host}" ];
                port = [ "-p" "${toString config.port}" ];
                warningDays = if (config.warningDays == 1000) then [] else [ "-w" "${toString config.warningDays}" ];
                timeout = [ "-t" "${toString config.timeout}" ];
                ocsp = [ "--ignore-ocsp" ];
                args = cmd ++ host ++ timeout ++ warningDays ++ port ++ ocsp;
                command_line = escapeShellArgs args;
              in
                {
                  command_name = "check_ssl_cert-${builtins.hashString "sha256" command_line}";
                  inherit command_line;
                };
          }; 
        } // stdOptions // { name = stdOptions.name "SSL";};
    }));
  };
}
