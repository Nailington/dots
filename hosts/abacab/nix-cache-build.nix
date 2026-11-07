{ pkgs, ... }:

{
  # Prebuild main only after updates have merged (or found no changes).
  # Each output link is a GC root; retain three successful revisions per client.
  systemd.services.nix-cache-build = {
    description = "Prebuild flake clients for abacab's binary cache";
    wants = [ "network-online.target" ];
    requires = [ "nix-flake-update.service" ];
    after = [ "network-online.target" "nix-flake-update.service" ];
    path = [ pkgs.git pkgs.nix pkgs.coreutils pkgs.findutils ];
    environment.HOME = "/var/lib/nix-cache-build";
    serviceConfig = {
      Type = "oneshot";
      User = "potter";
      Group = "users";
      StateDirectory = "nix-cache-build";
      WorkingDirectory = "/var/lib/nix-cache-build";
      Nice = 10;
      IOSchedulingClass = "idle";
      TimeoutStartSec = "infinity";
    };
    script = ''
      set -euo pipefail
      if [ ! -d checkout/.git ]; then
        git clone --depth 1 --branch main https://github.com/Nailington/dots.git checkout
      fi
      git -C checkout fetch --depth 1 origin main
      git -C checkout checkout --detach FETCH_HEAD
      revision=$(git -C checkout rev-parse HEAD)
      stamp=$(date -u +%Y%m%dT%H%M%S%N)
      failed=0
      for host in roundabout custard; do
        mkdir -p "roots/$host"
        output="$PWD/roots/$host/$stamp-$revision"
        if nix build --no-update-lock-file --max-jobs 2 --cores 3 \
          --out-link "$output" \
          "./checkout#nixosConfigurations.$host.config.system.build.toplevel"; then
          # Only prune this host after a successful build; failures keep old roots.
          find "roots/$host" -maxdepth 1 -type l -printf '%f\n' \
            | sort -r | tail -n +4 \
            | while IFS= read -r old; do rm -- "roots/$host/$old"; done
        else
          failed=1
        fi
      done
      exit "$failed"
    '';
  };
  systemd.timers.nix-cache-build = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 04:00:00";
      RandomizedDelaySec = "30m";
      Persistent = true;
    };
  };
}
