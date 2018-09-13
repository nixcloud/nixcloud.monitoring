# nixcloud.monitoring

This [nixpkgs](https://github.com/NixOS/nixpkgs) extension, called [nixcloud.monitoring](https://github.com/nixcloud/nixcloud.monitoring), let's you easily monitor your cloud servers' activities by active or passive monitoring which is displayed at status.nixcloud.io online.

We will extend `nixcloud-webservices` using `nixcloud.monitoring` soon and then services like `nixcloud.email` or `nixcloud.webservices` will get monitoring targets which will deploy once the services are configured automatically.

Demo at: https://status.nixcloud.io/qknight

# BETA program

As we major `nixcloud.monitoring` we invite you to use it and send feedback to us. All you need to do is this:

0. add nixcloud.monitoring to your configuration.nix

    cd /etc/nixos
    git clone http://github.com/nixcloud/nixcloud.monitoring

    vim configuration.nix and add the code below into the imports line:

    imports =
    [
      ./hardware-configuration.nix
      ./nixcloud.monitoring/nixcloud.monitoring.nix
    ];

1. at https://auth.nixcloud.io, register a new user, say it is called qknight
2. visit https://monitoring.nixcloud.io and login using OAuth2 from auth.nixcloud.io, just click 'login'
3. generate an apiKey for your user at https://status.nixcloud.io/api-keys
4. finally configure nixcloud.monitoring

    nixcloud.monitoring = {
      enable = true;
      apiKey = "4d3c5jdl-3kv6-6c92-43c2-bddcd6949e41";
    };

5. add targets, active or passive ones, see example below ...
6. `nixos-rebuild switch` will take your configuration into service
7. visit https://status.nixcloud.io/qknight and see the targets appearing

At the moment this service is for free but we will introduce a cost model soon.

## Pitfalls

* sometimes the ember.js based webpage gets disconnected and needs a manual reload
* sometimes the deployment for the monitoring gets stuck and some monitoring targets have to be removed using the webinterface until the deployment works again (this happens when the check_dns implementation changed and the client has a different implementation than the server. we work on an automation here)
* sometimes `nixcloud.monitoring` must be updated on your client, because it must be in sync with the server implementation

We work on all these things and our final goal is merge `nixcloud.monitoring` into `nixcloud-webservices`.

# Using nixcloud.monitoring

An active exampel would be:

```nix
nixcloud.monitoring = {
  enable = true;
  apiKey = "4d3c5jdl-3kv6-6c92-43c2-bddcd6949e41";
  targets = {
    active = {
      check_ssl_cert = [
        {
          host = "example.org";
        }
        {
          host = "nixcloud.io";
        }
        {
          host = "fractalide.com";
        }
      ];
      check_http = [
        {
          host = "nixcloud.io";
          url = "/main/en";
          contains = "individual";
        }
        {
          host = "kotalla.de";
          contains = "Aktuelles";
        }
      ];
    };
    # the passive implementation is _very_ BETA at the moment, please use with caution
    # we will update the implementation and documentation soon
    passive = [
      {
        host = "mail.lastlog.de";
        name = "sometest";
        # script = "some bash code"; # this declarative passive interface not tested well, don't use script for the time being
        timers = {
          check = 600;
          timeout = 660;
        };
      }
    ];
  };
};
```

## List rules timers

Using a systemd timer the target rule is pused periodically

```
systemctl list-timers --all
NEXT                          LEFT     LAST                          PASSED        UNIT                               ACTIVATES
Fri 2018-09-14 04:18:26 CEST  16h left Wed 2018-09-12 16:15:31 CEST  19h ago       systemd-tmpfiles-clean.timer       systemd-tmpfiles-clean.service
Fri 2018-09-14 05:31:08 CEST  17h left Wed 2018-09-12 17:28:09 CEST  18h ago       example.org-HTTP.timer            nixcloud.monitoring-active-example.com-HTTP.service
```

This needs to be done frequently so the target(s) don't get garbage collected. This means that a service like a webserver brings its own monitoring targets and whenever that service is put to rest the user will get a load of error emails but after a few days the errors/warnings stop. In the between time the user can either fix the service or remove the monitoring rules from the monitoring manually using the webinterface at status.nixcloud.io/qknight

# Usage

## Declarative

There are two ways in using `nixcloud.monitoring`:

* active monitoring

    Mainly used to check if a service is running from an outside your infrastructure. Meaning, the service checks are performed from a host called 'status.nixcloud.io' using IPv4/IPv6.

* passive monitoring

    Using passive monitoring you can upload the test results from within your own infrastructure. Security wise you don't have to make your infrastructure accessible from
    the outside to query test results or run tests.

In either case `nixcloud.monitoring` on your host will generate the required targets:

* Periodically register the monitoring target(s) at status.nixcloud.io
* Active: status.nixcloud.io will query your target and report the result(s) to the monitoring
* Passive: your host will also periodically upload passive results

Using this technique it is very easy to monitor aspects of your platform using Nix.

## Imperative

If you want to update a passive status 'manually' you can do this also since for each passive target we also create a script. 

Using passive monitoring you can update the status using a generated command line tool:

    nixcloud.monitoring-passive-result-mail.lastlog.de-sometest "快乐" "" 0

This will set the status message to 快乐, meaning 'happy' with the exit code 0, meaning 'OK'.

# Automatic monitoring

WARNING: Since this is an open BETA none of the below two might be implemented, contact us if you need that.

For services in `nixcloud-webservices` as `nixcloud.webservices` or `nixcloud.email` we generate default monitoring targets automatically. 
If some of the default monitoring implementations generate errors you can deactivate all the rules and provide your own implementation instead.

Disable the defualt monitoring targets using:

    nixcloud.webservices.mediawiki.<identifier>.monitoring = false;

Disable default monitoring for `nixcloud.email`:

    nixcloud.email.monitoring = false;

WARNING: Since this is an open BETA none of the above two might be implemented, contact us if you need that.

# Notifications

Notifications of status changes are sent via email.

## Privacy

Using `nixcloud.monitoring` exposes internals:

* security critical data (machine IPv4/IPv6, service/target names)
* personal data (passive checks run on your host, so you have to control what result string is sent)

# Copyright

The license can be found in [LICENSE](LICENSE).

For inquiries, please contact:

* nixcloud GmbH <info@nixcloud.io>

We are eager to help you getting into nixcloud.monitoring!

# Thanks

- [crushedpixel](https://github.com/crushedpixel)
- [aszlig](https://github.com/aszlig)
- [brauner](https://github.com/brauner)
- [seitz](https://github.com/seitz)
- [qknight](https://github.com/qknight)

Among all who didn't make it into this list! Thanks for helping with writing this!
