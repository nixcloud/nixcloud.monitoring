{ lib, config } :
with lib;
let
  stdOptions = (import ./lib/stdOptions.nix) {inherit lib; inherit config;};
in
 {
   check_http = mkOption {
    default = [];
    type = types.listOf (types.submodule ({ config, options, lib } : 
      {
        options = {
          port = mkOption {
            type = types.int;
            default = 80;
          };
          contains = mkOption {
            type = types.str;
            example = "Foobar";
            default = "";
            description = "A Word in a webpage which has to be there if the webservice works properly.";
          };
          url = mkOption {
            type = types.str;
            example = "/www";
            default = "";
            description = "A path added to the domain to query from.";
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
                cmd = [ "/opt/bin/check_http" ];
                host = [ "-H" "${toString config.host}" ];
                port = [ "-p" "${toString config.port}" ];
                ipv = if (config.ipv4) then [ "-4" ] else [ "-6" ];
                url = if (config.url == "") then [] else [ "-u" "${config.url}" ];
                contains = if (config.contains == "") then [] else [ "-s" "${config.contains}" ];
                follow = ["-f" "follow"];
                args = cmd ++ host ++ port ++ ipv ++ url ++ contains ++ follow;
                command_line = escapeShellArgs args;
              in
                {
                  command_name = "check_http-${builtins.hashString "sha256" command_line}";
                  inherit command_line;
                };
          }; 
        } // stdOptions // { name = stdOptions.name "HTTP";};
    }));
  };
}
