{ config, lib, pkgs, self, ... }:

{
  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "nix-cache-build";
      runtimeInputs = [ pkgs.systemd ];
      text = ''
        case "$#:$*" in
          0:) unit=nix-cache-build.service ;;
          1:--skip-custard) unit=nix-cache-build-skip-custard.service ;;
          1:--help|1:-h) echo 'Usage: nix-cache-build [--skip-custard]'; exit 0 ;;
          *) echo 'Usage: nix-cache-build [--skip-custard]' >&2; exit 2 ;;
        esac
        exec /run/wrappers/bin/sudo systemctl start --no-block "$unit"
      '';
    })
  ];

  # Keep existing log/GC-root paths while placing run state on the data disk.
  fileSystems."/var/lib/nix-cache-build" = {
    device = "/mnt/storage/nix-automation/cache-build";
    fsType = "none";
    options = [ "bind" ];
    depends = [ "/mnt/storage" ];
  };
  # Build main independently; the scheduled flow runs updates first when due.
  # Each output link is a GC root; retain three successful revisions per client.
  systemd.services = (lib.genAttrs [ "nix-cache-build" "nix-cache-build-skip-custard" ] (name:
  let
    skipCustard = name == "nix-cache-build-skip-custard";
  in {
    description = "Prebuild flake clients for abacab's binary cache";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" "nix-flake-update.service" "nix-flake-update-skip-custard.service" ];
    path = [
      pkgs.git pkgs.gh pkgs.nix pkgs.coreutils pkgs.findutils pkgs.util-linux
      self.packages.${pkgs.stdenv.hostPlatform.system}.update-local-packages
    ];
    environment.HOME = "/var/lib/nix-cache-build";
    environment.TMPDIR = "/var/lib/nix-automation-tmp";
    unitConfig.RequiresMountsFor = [ "/var/lib/nix-cache-build" "/var/lib/nix-automation-tmp" ];
    serviceConfig = {
      Type = "oneshot";
      User = "potter";
      Group = "users";
      StateDirectory = "nix-cache-build";
      WorkingDirectory = "/var/lib/nix-cache-build";
      LoadCredential = "github-token:${config.age.secrets.github-automation.path}";
      Nice = 10;
      IOSchedulingClass = "idle";
      TimeoutStartSec = "infinity";
    };
    script = ''
      set -euo pipefail
      exec 9>build.lock
      flock 9
      targets=(roundabout custard)
      if ${lib.boolToString skipCustard}; then
        packages=$(update-local-packages --skip-custard --list-build-targets)
        mapfile -t targets <<< "$packages"
      fi
      token=$(cat "$CREDENTIALS_DIRECTORY/github-token")
      pending=$(GH_TOKEN="$token" gh pr list --repo Nailington/dots --base main --state open \
        --json headRefName,url \
        --jq '.[] | select(.headRefName | startswith("automation/flake-update-")) | .url')
      if [ -n "$pending" ]; then
        echo "An update PR still needs attention; blocking this build: $pending" >&2
        exit 1
      fi
      if [ ! -d checkout/.git ]; then
        git clone --depth 1 --branch main https://github.com/Nailington/dots.git checkout
      fi
      git -C checkout fetch --depth 1 origin main
      git -C checkout checkout --detach FETCH_HEAD
      revision=$(git -C checkout rev-parse HEAD)
      stamp=$(date -u +%Y%m%dT%H%M%S%N)
      report_build_failure() {
        local target="$1" title issue token body
        title="Cache build failed: $target at $revision"
        token=$(cat "$CREDENTIALS_DIRECTORY/github-token") || return 1
        issue=$(GH_TOKEN="$token" gh issue list --repo Nailington/dots --state open \
          --search "\"$title\" in:title" --json number --jq '.[0].number // empty') || return 1
        if [ -n "$issue" ]; then
          echo "Build failure already reported in issue #$issue; not tagging again."
          return 0
        fi
        body="$PWD/build-failure-$target-$revision.md"
        {
          printf '@HammerPot @Nailington — please review this failed cache build.\n\n'
          printf 'Build target: %s\nCommit: https://github.com/Nailington/dots/commit/%s\n' "$target" "$revision"
          printf '\nThe system was not activated. Previous successful cache roots are preserved.\n'
          printf '\nLogs on abacab: sudo journalctl -u ${name}.service\n'
        } > "$body"
        GH_TOKEN="$token" gh issue create --repo Nailington/dots --title "$title" \
          --body-file "$body" --assignee HammerPot --assignee Nailington
      }
      failed=0
      for target in "''${targets[@]}"; do
        roots="roots/$target"
        installable="./checkout#nixosConfigurations.$target.config.system.build.toplevel"
        if ${lib.boolToString skipCustard}; then
          roots="roots/packages/$target"
          installable="./checkout#packages.x86_64-linux.$target"
        fi
        mkdir -p "$roots"
        output="$PWD/$roots/$stamp-$revision"
        if nix build --no-update-lock-file --max-jobs 2 --cores 3 \
          --out-link "$output" \
          "$installable"; then
          # Only prune this host after a successful build; failures keep old roots.
          find "$roots" -maxdepth 1 -type l -printf '%f\n' \
            | sort -r | tail -n +4 \
            | while IFS= read -r old; do rm -- "$roots/$old"; done
        else
          failed=1
          # Merged PRs cannot request another review; report a build failure as
          # an issue, once per host/revision. Successful builds never tag anyone.
          report_build_failure "$target" || echo "Could not report $target build failure to GitHub." >&2
        fi
      done
      exit "$failed"
    '';
  })) // {

  nix-cache-scheduled = {
    description = "Update the flake when due, then prebuild the binary cache";
    path = [ pkgs.coreutils pkgs.systemd ];
    unitConfig.RequiresMountsFor = [ "/var/lib/nix-flake-update" ];
    serviceConfig = {
      Type = "oneshot";
      TimeoutStartSec = "infinity";
    };
    script = ''
      set -euo pipefail
      # Sunday through Saturday, matching the updater's success marker.
      week=$(date -d "today -$(date +%w) days" +%F)
      week_file=/var/lib/nix-flake-update/last-successful-update-week
      if [ ! -f "$week_file" ] || [ "$(cat "$week_file")" != "$week" ]; then
        systemctl start nix-flake-update.service
      fi
      # A failed update exits above; unresolved PRs are checked by the build.
      systemctl start nix-cache-build.service
    '';
  };
  };
  systemd.timers.nix-cache-build = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      Unit = "nix-cache-scheduled.service";
      OnCalendar = "*-*-* 04:00:00";
      RandomizedDelaySec = "30m";
      Persistent = true;
    };
  };
}
