{ config, lib, pkgs, self, ... }:

let
  qbittorrentInitialConfig = pkgs.writeText "qbittorrent-initial.conf" ''
    [LegalNotice]
    Accepted=true
    [BitTorrent]
    Session\DefaultSavePath=/mnt/storage/torrents
    Session\Interface=tailscale0
    Session\InterfaceName=tailscale0
    [Network]
    PortForwardingEnabled=false
    [Preferences]
    WebUI\Address=127.0.0.1
    WebUI\LocalHostAuth=false
  '';
in
{
  imports = [
    ./hardware-configuration.nix
    ./disk.nix

    ../../modules/nixos/common.nix
    ../../modules/nixos/tailscale.nix
    ./nginx.nix
    ./cron.nix
    # Mullvad egress comes from a Tailscale exit node, not the Mullvad daemon.
    # no desktop / gaming on this host
  ];

  networking.hostName = "abacab";

  # Headless: systemd-networkd + static IPv4 (override NetworkManager from common.nix)
  networking.networkmanager.enable = lib.mkForce false;
  networking.useNetworkd = true;
  networking.useDHCP = false;
  networking.nameservers = [
    "1.1.1.1"
    "1.0.0.1"
  ];
  services.resolved.enable = true;
  systemd.network.enable = true;
  systemd.network.networks."10-uplink" = {
    matchConfig.Name = "en* eth*";
    address = [ "45.92.216.66/23" ];
    gateway = [ "45.92.216.1" ];
    networkConfig = {
      DHCP = "no";
      DNS = [
        "1.1.1.1"
        "1.0.0.1"
      ];
      IPv6AcceptRA = false;
    };
  };

  # Existing data disk — mount only, never format. Kept out of disko on purpose.
  fileSystems."/mnt/storage" = {
    device = "/dev/disk/by-uuid/39ed1bbb-0ebf-43fd-a02e-62187377b916";
    fsType = "ext4";
    options = [
      "defaults"
      "nofail"
      "x-systemd.device-timeout=10s"
    ];
  };

  # Build custard's ARM image using QEMU user-mode emulation.
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  # Private binary cache — bind only to this host's Tailscale IPv4 address.
  age.secrets.abacab-cache.file = ../../secrets/abacab-cache.age;
  services.nix-serve = {
    enable = true;
    package = pkgs.nix-serve-ng;
    bindAddress = "100.120.61.10";
    port = 5000;
    openFirewall = false; # tailscale0 is already trusted; no public port.
    secretKeyFile = config.age.secrets.abacab-cache.path;
  };
  systemd.services.nix-serve = {
    requires = [ "tailscaled.service" ];
    after = [ "tailscaled.service" ];
    path = [ pkgs.tailscale ];
    preStart = ''
      tailscale wait
      tailscale ip --assert=100.120.61.10
    '';
    serviceConfig.TimeoutStartSec = "infinity";
  };

  # Custard's existing managed user key authenticates its Nix daemon.
  users.groups.nix-builder = { };
  users.users.nix-builder = {
    isSystemUser = true;
    group = "nix-builder";
    useDefaultShell = true;
    openssh.authorizedKeys.keys = [
      ("restrict " + lib.trim (builtins.readFile ../../secrets/ssh/custard/id_ed25519.pub))
    ];
  };
  nix.settings = {
    trusted-users = [ "nix-builder" ];
    # Leave capacity for the server's other services, including during ARM emulation.
    max-jobs = 2;
    cores = 3;
    # Sign remote-build outputs too, so custard can verify copied results.
    secret-key-files = [ config.age.secrets.abacab-cache.path ];
  };

  # Update in an automation-owned checkout, never in Potter's working tree.
  # Credentials are decrypted outside the store and passed through systemd.
  age.secrets.github-automation.file = ../../secrets/github-automation.age;
  systemd.services.nix-flake-update = {
    description = "Update flake packages and merge evaluated updates through a PR";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    before = [ "nix-cache-build.service" ];
    path = [
      pkgs.git pkgs.gh pkgs.nix pkgs.jq pkgs.coreutils
      self.packages.${pkgs.stdenv.hostPlatform.system}.update-local-packages
    ];
    environment = {
      HOME = "/var/lib/nix-flake-update";
      GIT_TERMINAL_PROMPT = "0";
      GH_PROMPT_DISABLED = "1";
    };
    serviceConfig = {
      Type = "oneshot";
      User = "potter";
      Group = "users";
      StateDirectory = "nix-flake-update";
      WorkingDirectory = "/var/lib/nix-flake-update";
      LoadCredential = "github-token:${config.age.secrets.github-automation.path}";
      UMask = "0077";
      Nice = 10;
      IOSchedulingClass = "idle";
      TimeoutStartSec = "infinity";
    };
    script = ''
      set -euo pipefail
      GH_TOKEN=$(cat "$CREDENTIALS_DIRECTORY/github-token")
      export GH_TOKEN
      export GITHUB_TOKEN="$GH_TOKEN"
      export NIX_CONFIG="access-tokens = github.com=$GH_TOKEN"
      repo=Nailington/dots
      pending=$(gh pr list --repo "$repo" --base main --state open \
        --json headRefName,url \
        --jq '.[] | select(.headRefName | startswith("automation/flake-update-")) | .url')
      if [ -n "$pending" ]; then
        echo "An update PR still needs attention; blocking this run: $pending" >&2
        exit 1
      fi
      stamp=$(date -u +%Y%m%dT%H%M%S)-$RANDOM
      run="$PWD/runs/$stamp"
      mkdir -p "$run"
      exec > >(tee -a "$run/run.log") 2>&1
      if [ ! -d checkout/.git ]; then
        git clone --depth 1 --branch main "https://github.com/$repo.git" checkout
      fi
      cd checkout
      git fetch --depth 1 origin main
      base=$(git rev-parse origin/main)
      branch="automation/flake-update-$stamp"
      # Discard only this service's leftovers from a prior interrupted run.
      git checkout -f -B "$branch" origin/main
      actor=$(gh api user --jq .login)
      actor_id=$(gh api user --jq .id)
      git config user.name "$actor"
      git config user.email "$actor_id+$actor@users.noreply.github.com"
      git config credential.helper '!gh auth git-credential'

      updates_ok=true
      nix flake update || updates_ok=false
      update-local-packages --flake "$PWD" --all || updates_ok=false
      git add --update -- flake.nix flake.lock pkgs
      if git diff --cached --quiet; then
        if ! "$updates_ok"; then
          echo "Updating failed without a publishable diff; see $run/run.log" >&2
          exit 1
        fi
        echo "No package or input updates; cache build may proceed."
        exit 0
      fi
      git commit -m "Update flake inputs and local packages ($stamp)"
      head=$(git rev-parse HEAD)

      # Check all exported package systems and explicitly force every host.
      # Darwin is evaluated here, never built or activated on Linux.
      eval_ok=true
      nix flake check --no-build --all-systems --no-update-lock-file || eval_ok=false
      for kind in nixosConfigurations darwinConfigurations homeConfigurations; do
        if nix eval --no-update-lock-file --json ".#$kind" \
          --apply builtins.attrNames > "$run/$kind.json"; then
          while IFS= read -r host; do
            case "$kind" in
              nixosConfigurations) target="config.system.build.toplevel.drvPath" ;;
              darwinConfigurations) target="system.drvPath" ;;
              homeConfigurations) target="activationPackage.drvPath" ;;
            esac
            nix eval --no-update-lock-file --raw ".#$kind.\"$host\".$target" || eval_ok=false
            printf '\n'
          done < <(jq -r '.[]' "$run/$kind.json")
        else
          eval_ok=false
        fi
      done
      # The exact committed tree must be the tree checked above.
      git diff --quiet && git diff --cached --quiet || eval_ok=false
      git fetch --depth 1 origin main
      base_ok=true
      if [ "$(git rev-parse origin/main)" != "$base" ]; then base_ok=false; fi
      {
        printf 'Updates flake inputs and the supported local package pins/hashes.\n\n'
        printf -- '- Package/input updates completed: %s\n' "$updates_ok"
        printf -- '- All-system flake and explicit host evaluations passed: %s\n' "$eval_ok"
        printf -- '- Main unchanged during evaluation: %s\n' "$base_ok"
        printf '\nEvaluated commit: %s. No system activation is performed.\n' "$head"
        printf '\nDetailed logs on abacab: %s/run.log.\n' "$run"
      } > "$run/pr-body.md"
      git push origin "HEAD:refs/heads/$branch"
      pr=$(gh pr create --repo "$repo" --base main --head "$branch" \
        --title "Update flake inputs and local packages ($stamp)" \
        --body-file "$run/pr-body.md")
      printf '%s\n' "$pr" | tee "$run/pr-url"

      request_review() {
        for reviewer in HammerPot Nailington; do
          gh pr edit "$pr" --repo "$repo" --add-assignee "$reviewer" || true
          if [ "$reviewer" != "$actor" ]; then
            gh pr edit "$pr" --repo "$repo" --add-reviewer "$reviewer" || true
          else
            echo "$reviewer is the PR author; assigned instead of requesting self-review."
          fi
        done
      }
      if ! "$updates_ok" || ! "$eval_ok" || ! "$base_ok"; then
        request_review
        echo "Update PR requires review; cache build is blocked: $pr" >&2
        exit 1
      fi
      # Respect repository protection and reject a concurrently changed PR head.
      if ! gh pr merge "$pr" --repo "$repo" --squash --match-head-commit "$head"; then
        request_review
        exit 1
      fi
      if [ "$(gh pr view "$pr" --repo "$repo" --json state --jq .state)" != MERGED ]; then
        echo "PR is not merged yet; cache build remains blocked: $pr" >&2
        exit 1
      fi
    '';
  };

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

  # This host kexec'd in BIOS (not EFI). systemd-boot cannot boot that.
  boot.loader.systemd-boot.enable = false;
  boot.loader.efi.canTouchEfiVariables = false;
  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
    efiSupport = true;
    efiInstallAsRemovable = true;
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  # hashedPassword is only applied on first user creation unless this is false.
  users.mutableUsers = true;
  users.users.potter = {
    isNormalUser = true;
    description = "Potter";
    extraGroups = [
      "wheel"
      "qbittorrent"
    ];
    hashedPassword = "$6$.Md2vHMcUm4HZqz5$RcB0ZyyJ3yxk4uMuQZhQB.KHkngfOB9Wxg05aKy477DB4ZN3gpG/Ckdoo29aMsZktMvukCsMCNbbOhWNehDQ1.";
  };

  # SSH keys: GitHub .keys + optional lib/ssh-keys.nix (modules/nixos/ssh-github.nix)

  security.sudo.wheelNeedsPassword = true;

  # Minecraft Java servers — ftc.hammerpot.dev uses port 40002; additional server on 40003.
  # add more ports as needed for servers
  networking.firewall.allowedTCPPorts = [ 40002 40003 ];
  networking.firewall.allowedUDPPorts = [ 40002 40003 ];

  # The Web UI is loopback-only. Reach it from another machine with:
  # ssh -L 8080:127.0.0.1:8080 abacab
  services.qbittorrent = {
    enable = true;
    openFirewall = false;
    webuiPort = 8080;
  };

  # Prepare downloads only after the data disk mounts, so a missing disk
  # cannot silently fill the root filesystem.
  systemd.services.qbittorrent-storage = {
    description = "Prepare qBittorrent storage on abacab";
    requires = [ "mnt-storage.mount" ];
    after = [ "mnt-storage.mount" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.coreutils}/bin/install -d -m 2770 -o potter -g qbittorrent /mnt/storage/torrents";
    };
  };
  systemd.services.qbittorrent = {
    requires = [ "tailscaled.service" "qbittorrent-storage.service" ];
    after = [ "tailscaled.service" "qbittorrent-storage.service" ];
    # Seed once so Web UI password and torrent preferences survive restarts.
    preStart = ''
      configFile=/var/lib/qBittorrent/qBittorrent/config/qBittorrent.conf
      if [ ! -e "$configFile" ]; then
        ${pkgs.coreutils}/bin/install -Dm600 ${qbittorrentInitialConfig} "$configFile"
      fi
    '';
    serviceConfig = {
      # A second guard behind qBittorrent's own interface binding: peer
      # sockets cannot fall back to the VPS's public network interface.
      RestrictNetworkInterfaces = "lo tailscale0";
      UMask = "0007";
    };
  };

  environment.systemPackages = with pkgs; [
    htop
    tmux
  ];

  system.stateVersion = "25.11";
}
