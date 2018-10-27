#set the most recent default implementations for active checks
lib: config: {
  check_http       = (import ./active/check_http_3.nix)      {inherit lib; inherit config;};
  check_ssh        = (import ./active/check_ssh_1.nix)       {inherit lib; inherit config;};
  check_ping       = (import ./active/check_ping_1.nix)      {inherit lib; inherit config;};
  check_ssl_cert   = (import ./active/check_ssl_cert_2.nix)  {inherit lib; inherit config;};
  check_smtp       = (import ./active/check_smtp_1.nix)      {inherit lib; inherit config;};
  check_dns        = (import ./active/check_dns_1.nix)       {inherit lib; inherit config;};
  check_hydra      = (import ./active/check_hydra_1.nix)     {inherit lib; inherit config;};
}
