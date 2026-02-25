# Tailscale client configuration for NixOS
# Add this to your /etc/nixos/configuration.nix

{ config, pkgs, ... }:

{
  # Tailscale client
  services.tailscale = {
    enable = true;
    # Use your own Tailscale auth key (get it from https://login.tailscale.com/admin/settings/keys)
    # Or run: sudo tailscale up --login-server=https://login.tailscale.com
    useSystemKey = true;
  };

  # Allow Tailscale to manage firewall
  networking.firewall.trustedInterfaces = [ "tailscale0" ];

  # Optional: Enable IP forwarding for routing
  boot.kernel.sysctl = { "net.ipv4.ip_forward" = 1; };
}
