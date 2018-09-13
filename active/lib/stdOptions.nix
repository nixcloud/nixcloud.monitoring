{ lib, config }:
with lib;  {
    # this is a function so it can be generalized easily
    name = x: mkOption {
      type = types.str;
      default = x;
      description = ''
        Service name shown in the status.nixcloud.io monitoring frontend. The string "`host`-`name`" must be globally unique taken all the passive and active targets together.
      '';
    };
    host = mkOption {
      description = ''The target hostname (`example.com`) or IPv4/IPv6 you want to monitor.'';
      type = types.str;
      default = "";
      example = "example.com";
    };
    tags = mkOption {
      type = types.listOf types.str;
      description = ''By default the `host` will be added to tags but one can add more tags for later grouping of services.'';
      default = [];
    };
    public = mkOption {
      default = if (config ? nixcloud && config.nixcloud ? monitoring) then config.nixcloud.monitoring.public else false;
      type = types.bool;
      description = "Show/hide monitoring results for this specific target. Setting this to 'false' requires a license or service uploads will fail.";
    }; 
    ipv4 = mkOption {
      description = ''Explicitly check the service using IPv4. If also IPv6 is enabled, you will have two service checks per service.'';
      type = types.bool;
      example = true;
      default = true;
    };
    ipv6 = mkOption {
      description = ''Explicitly check the service using IPv6. If also IPv4 is enabled, you will have two service checks per service.'';
      type = types.bool;
      example = true;
      default = true;
    };
  }
