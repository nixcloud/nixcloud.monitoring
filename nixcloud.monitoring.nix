{ config, pkgs, lib, ...} @ toplevel:
with lib;

{
  options.nixcloud.monitoring = {
    enable = mkEnableOption "nixcloud.monitoring";
    apiKey = mkOption {
      example = "zws0mxsjyhzv9102vwgnzbm2r";
      description = "API key used with status.nixcloud.io";
    };
    apiHost = mkOption {
      default = "https://status.nixcloud.io";
      description = "API host used to upload monitoring rules for various services";
    };
    public = mkOption {
      default = true;
      type = types.bool;
      description = "A global setting to show/hide monitoring results for all targets. Setting this to 'false' requires a license or service uploads will fail.";
    };
    targets = mkOption {
      type = types.submodule ({ name, ... } : (import ./options.nix) { inherit name config toplevel lib options; });
      description = ''
        A set of 'active' or 'passive' targets (services) to monitor:

        * Active monitoring is useful for TLS cert checking or tests from outside in general. 
        * Passive monitoring is useful for internal machine state monitoring or backups which are easily pushed but hard to pull security wise. You can now also monitor devices which are not reachable from the monitoring, for instance devices behind NAT or firewalls.
      '';
    };
  };

  config =
    let
      cfg = config.nixcloud.monitoring;
      toListOfSets = name: list: (fold (element: container: container ++ [{name = "${name}"; config = element;}]) [] list);

      #### < active > ###################################################################################################################

      createActiveSystemDTimer = element: container: 
      let
        uniqueName = "${element.config.host}-${element.config.name}";
      in mkMerge [ container {
          "${uniqueName}" = {
            description = "nixcloud.monitoring ${uniqueName}";
            wantedBy    = [ "timers.target" ];

            timerConfig = {
              OnUnitActiveSec = "24hours";
              OnBootSec = "2min";
              Unit = "nixcloud.monitoring-active-${uniqueName}.service";
              Persistent = "yes";
              AccuracySec = "1m";
              RandomizedDelaySec = "1min";
            };
          };
      }];
      activeTargets = 
        let
          activeCommandNames = filter (x: x != "_module") (attrNames cfg.targets.active);
        in
          fold (element: container: container ++ (toListOfSets "${element}" cfg.targets.active.${element})) [] activeCommandNames;

      activeSystemDServices =
        fold createActiveSystemDService {} activeTargets;
      createActiveSystemDService = element: container:
        let
          uniqueName = "${element.config.host}-${element.config.name}";
          scriptName = "nixcloud.monitoring-active-${uniqueName}";
          options = (import ./client_active_targets.nix) lib {};
          hashOptions = (import ./hash.nix) lib;
          h = hashOptions options."${element.name}";
          payload = removeAttrs element.config [ "generate" "_module" ];
          payload4 = payload // { ipv6=false; name = payload.name + " (IPv4)"; };
          payload6 = payload // { ipv4=false; name = payload.name + " (IPv6)"; };
          filteredAndSerializedCommand = payload: 
            { 
              #id = "${payload.host}-${payload.name}"; 
              command = {
                name = element.name;
                hash = h;
              };
              payload = payload;
            };
        in 
          assert (element.config.ipv4 == true || element.config.ipv6 == true) || abort "monitoring.nixcloud entry for ${uniqueName} has both ipv4 and ipv6 set to false. At least one of those must be enabled.";
          mkMerge [ container {
          "${scriptName}" = {
            description = "nixcloud.monitoring active monitoring for target ${uniqueName}";
            #wantedBy = [ "multi-user.target" ];
            after = [ "network.target" ];
            # FIXME: do proper exit code handling
            script = ''
              if [[ ${toString element.config.ipv4} == 1 ]]; then
              ${pkgs.curl}/bin/curl -X POST --header "Authorization: ApiKey ${cfg.apiKey}" --header "Content-Type: application/json" --data '${builtins.toJSON  (filteredAndSerializedCommand payload4)}' ${cfg.apiHost}/api/services
              fi
              if [[ ${toString element.config.ipv6} == 1 ]]; then
              ${pkgs.curl}/bin/curl -X POST --header "Authorization: ApiKey ${cfg.apiKey}" --header "Content-Type: application/json" --data '${builtins.toJSON  (filteredAndSerializedCommand payload6)}' ${cfg.apiHost}/api/services
              fi
              exit 0
            '';
            serviceConfig = {
              User = "nixcloud-monitoring";
              Group = "nixcloud-monitoring";
              Type = "oneshot";
            };
          };
      }];

      #### < /active > ###################################################################################################################

      #### < passive > ###################################################################################################################

      # a passive target has two properties:
      #  - target rule upload
      #  - target result upload, which can be
      #    - imperative:
      #      result is pushed via our script from a third party script, as a backup for instance
      #    - declarative
      #      when `config.script` is implemented results are pushed via systemd timer invocations.
      #      this is handy when you don't want to call the result upload script manually

      # FIXME: passive timers need a closer look now that they are in use
      #         - check the freshness_threshold           660 # minutes
      #         - implement a custom 'class' per passive target on the server, see check_passive_24x7,notify_24h_24x7
      #         - check if the systemd timer for results is triggered often enough and so on...

      passiveTargets = toListOfSets "passive" cfg.targets.passive;

      ######### <RULES> #######################################################################################################
      createPassiveTargetRuleSystemDTimer = element: container:
        let
          uniqueName = "${element.config.host}-${element.config.name}";
        in mkMerge [ container {
          "${uniqueName}" = {
            description = "nixcloud.monitoring rule upload timer for ${uniqueName}";
            wantedBy    = [ "timers.target" ];

            timerConfig = {
              OnUnitActiveSec = "${toString element.config.timers.check} minutes";
              OnBootSec = "2min";
              Unit = "nixcloud.monitoring-passive-rule-${uniqueName}.service";
              Persistent = "yes";
              AccuracySec = "1m";
              RandomizedDelaySec = "1min";
            };
          };
      }];
      passiveTargetRuleSystemDServices = fold createPassiveTargetRuleSystemDService {} passiveTargets;
      createPassiveTargetRuleSystemDService = element: container:
        assert (element.config.timers.check < element.config.timers.timeout) || abort "See nixcloud.monitoring's passive timers. timers.check must be smaller than timers.timeout!";
        let
          uniqueName = "${element.config.host}-${element.config.name}";
          scriptName = "nixcloud.monitoring-passive-rule-${uniqueName}";
          payload = { 
            # we do not want to see nor do we need 'the users script' on the remote side
            payload = removeAttrs element.config [ "_module" "script" ] // { script = ""; }; 
          };
        in mkMerge [ container { 
          "${scriptName}" = {
            description = "nixcloud.monitoring ${uniqueName}";
            wantedBy = [ "multi-user.target" ];
            after = [ "network.target" ];
            script = ''
              ${pkgs.curl}/bin/curl -X POST --header "Authorization: ApiKey ${cfg.apiKey}" --header "Content-Type: application/json" --data '${builtins.toJSON payload}' ${cfg.apiHost}/api/services
            '';
            serviceConfig = {
              User  = "nixcloud-monitoring";
              Group = "nixcloud-monitoring";
              Type  = "oneshot";
            };
          };
      }];
      ######### </RULES> #######################################################################################################
      ######### <RESULTS> #######################################################################################################
      declarativePassiveTargets = filter (x: x.config.script != "") passiveTargets;
      passiveTargetResultSystemDServices = fold createPassiveTargetResultSystemDService {} declarativePassiveTargets;
      createPassiveTargetResultSystemDService = element: container:
        assert (element.config.timers.check < element.config.timers.timeout) || abort "See nixcloud.monitoring's passive timers. timers.check must be smaller than timers.timeout!";
        let
          uniqueName = "${element.config.host}-${element.config.name}";
          scriptName = "nixcloud.monitoring-passive-result-${uniqueName}";
        in mkMerge [ container { 
          "${scriptName}" = {
            description = "nixcloud.monitoring ${uniqueName}";
            wantedBy = [ "multi-user.target" ];
            # FIXME would be nice if we could execute this after the rule upload and could use systemd depedencies for that
            after = [ "network.target" ];
            script = ''
              # initializing the variables
              exit=3

              status="not set, your script is incomplete"
              perfdata=""
              # hopefully setting the variables correctly
              ${element.config.script}
              # uploading the data
              ${createPassiveScript element}/bin/nixcloud.monitoring-passive-${uniqueName} "$status" "$perfdata" $exit
            '';
            serviceConfig = {
              User  = "nixcloud-monitoring";
              Group = "nixcloud-monitoring";
              Type  = "oneshot";
            };
          };
      }];
      createPassiveTargetResultSystemDTimer = element: container:
        let
          uniqueName = "${element.host}-${element.name}";
        in mkMerge [ container {
          "${uniqueName}" = {
            description = "nixcloud.monitoring result upload timer for ${uniqueName}";
            wantedBy    = [ "timers.target" ];

            timerConfig = {
              OnUnitActiveSec = "${toString element.timers.check} minutes";
              OnBootSec = "2min";
              Unit = "nixcloud.monitoring-passive-result-${uniqueName}.service";
              Persistent = "yes";
              AccuracySec = "1m";
              RandomizedDelaySec = "1min";
            };
          };
      }];
      passiveScripts = map createPassiveScript passiveTargets;
      createPassiveScript = element: let
        uniqueName = "${element.config.host}-${element.config.name}";
      in pkgs.writeScriptBin "nixcloud.monitoring-passive-result-${uniqueName}"
      ''
        #! ${pkgs.stdenv.shell}
        # check command line arguments
        if [ "$#" -ne 3 ]; then
            echo "Illegal number of parameters"
            echo "Usage: $0 \"output string\" \"perfdata\" status" 
            echo "     where status can be 0,1,2 or 3"
            echo "Example:"
            echo "     $0 \"critical error\" \"\" 2"
            exit 1
        fi

        # check for proper integer
        if [ "$3" -eq "$3" ] 2>/dev/null
        then
            if [ "$3" -lt "0" ] || [ "$3" -gt "3" ]; then
                echo "ERROR: status must be either 0 OK, 1, WARNING , 2 ERROR or 3 UNKNOWN"
                exit 1
            fi
        else
            echo "ERROR: first parameter must be an integer."
            exit 1
        fi

        # http://bigdatums.net/2016/11/21/using-variables-in-jq-command-line-json-parser/
        json=$(echo "{}" | ${pkgs.jq}/bin/jq -c --arg output "$1" --arg perfdata "$2" --arg state "$3" '{host: "${element.config.host}", name: "${element.config.name}", output: $output, perfdata: $perfdata, state: $state | tonumber }')
        cmd="${pkgs.curl}/bin/curl -X POST --header \"Authorization: ApiKey ${cfg.apiKey}\" --header \"Content-Type: application/json\" --data '$json' ${cfg.apiHost}/api/services/results"
        eval $cmd
        exit $status
      '';
      ######### <RESULTS> #######################################################################################################
      #### < /passive > ###################################################################################################################

      # checks if the IDs, combination of host + name, is unique among all targets
      isUnique = allTargets:
        let
          list = map (element: "${element.config.host}-${element.config.name}") allTargets;
        in
          (length list) == (length (unique list));

      findDuplicates = list: findDuplicates' list "";
      findDuplicates' = list: duplicates: 
        let
          h = head list;
          t = tail list;
          d = fold (e: c: if (e.config.host == h.config.host && e.config.name == h.config.name) then c + "* host = ${e.config.host} \n* name = ${e.config.name}\n\n" else c) duplicates t;
       in
         if (length t == 0) then d else (findDuplicates' t d); #'

      allTargets = activeTargets ++ passiveTargets;
      checkTargets = x: assert (isUnique allTargets) || abort "Your list of nixcloud.monitoring.targets, both passive and active taken together, is not unique!\n\nLook for:\n${findDuplicates allTargets}"; x;
    in
      mkIf cfg.enable {
        users.extraUsers  = [ { name = "nixcloud-monitoring"; group = "nixcloud-monitoring";} ];
        users.extraGroups = [ { name = "nixcloud-monitoring";} ];

        # includes scripts for 'declarative passive targets' and 'imperative passive targets'
        environment.systemPackages = checkTargets 
          passiveScripts; # ++ [ nixcloud-monitoring-binary ];

        systemd.services = checkTargets
          mkMerge [
            activeSystemDServices
            passiveTargetRuleSystemDServices
            passiveTargetResultSystemDServices
          ];

        systemd.timers = checkTargets
          mkMerge [
            (fold createActiveSystemDTimer {} activeTargets)
            (fold createPassiveTargetRuleSystemDTimer   {} passiveTargets)
            (fold createPassiveTargetResultSystemDTimer {} declarativePassiveTargets)
          ];
      };
    }
