{ lib, config } :
with lib;
let
  stdOptions = (import ./lib/stdOptions.nix) {inherit lib; inherit config;};
in
 {
   check_hydra = mkOption {
    default = [];
    type = types.listOf (types.submodule ({ config, options, lib } : 
      {
        options = {
          project = mkOption {
            type = types.string;
            example = "nixcloud-webservices";
            default = "";
            description = "";
          };
          jobset = mkOption {
            type = types.string;
            example = "nixos-unstable";
            default = "";
            description = "";
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
                cmd = [ "/opt/bin/check_hydra" ];
                host = [ "-a" "url=${toString config.host}" ];
                project = [ "-a" "project=${toString config.project}" ];
                jobset = [ "-a" "jobset=${toString config.jobset}" ];
                args = cmd ++ host ++ project ++ jobset;
                command_line = escapeShellArgs args;
              in
                {
                  command_name = "check_dns-${builtins.hashString "sha256" command_line}";
                  inherit command_line;
                };
          }; 
        } // stdOptions // { name = stdOptions.name "${config.project}_${config.jobset}";};
    }));
  };
}
