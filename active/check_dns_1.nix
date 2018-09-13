{ lib, config } :
with lib;
let
  stdOptions = (import ./lib/stdOptions.nix) {inherit lib; inherit config;};
in
 {
   check_dns = mkOption {
    default = [];
    type = types.listOf (types.submodule ({ config, options, lib } : 
      {
        options = {
          server = mkOption {
            type = types.string;
            example = "1.2.3.4";
            default = "";
            description = "Optional DNS server you want to use for the lookup";
          };
          timeout = mkOption {
            type = types.int;
            default = 10;
            description = "Seconds before connection times out";
          };
          expected-address = mkOption {
            type = types.string;
            example = "1.2.3.4";
            default = "";
            description = ''
              Optional IP-ADDRESS you expect the DNS server to return. HOST must end with
              a dot (.). This option can be repeated multiple times (Returns OK if any
              value match). If multiple addresses are returned at once, you have to match
              the whole string of addresses separated with commas (sorted alphabetically).
              If you would like to test for the presence of a cname, combine with -n param.
            '';
          };
          expect-authority = mkOption {
            type = types.string;
            default = "";
            description = ''
              Optionally expect the DNS server to be authoritative for the lookup
            '';
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
                cmd = [ "/opt/bin/check_dns" ];
                host = [ "-H" "${toString config.host}" ];
                server = if (config.server == "") then [] else [ "-s" "${config.server}" ];
                expected-address = if (config.expected-address == "") then [] else [ "-a" "${config.expected-address}" ];
                timeout = [ "-t" "${toString config.timeout}" ];
                expect-authority = if (config.expect-authority == "") then [] else [ "-A" "${config.expect-authority}" ];
                args = cmd ++ host ++ server ++ timeout ++ expected-address ++ expect-authority;
                command_line = escapeShellArgs args;
              in
                {
                  command_name = "check_dns-${builtins.hashString "sha256" command_line}";
                  inherit command_line;
                };
          }; 
        } // stdOptions // { name = stdOptions.name "DNS";};
    }));
  };
}
