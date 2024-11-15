{
  config,
  pkgs,
  lib,
  hostParams,
  ...
}: let
  username = hostParams.username;
  dotfilesSyncScript = pkgs.writeScript "dotfiles-sync.sh" (builtins.readFile ../../bin/dotfiles-sync.sh);
in {
  "dotfiles-sync" = {
    description = "Sync dotfiles to git repository";
    path = with pkgs; [
      bash
      git
      coreutils
      findutils
      libnotify
      rsync
      stow
      openssh
      util-linux
    ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${dotfilesSyncScript}";
      IOSchedulingClass = "idle";
      CPUSchedulingPolicy = "idle";
    };

    environment = {
      GIT_SSH_COMMAND = "ssh -i /home/${username}/.ssh/id_ed25519";
      HOME = "/home/${username}";
    };
    wants = ["dbus.socket"];
    after = ["dbus.socket"];
  };
}
