{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.kopia;
  helpers = import ./helpers.nix { inherit lib; };

  btrfsExe = lib.getExe' pkgs.btrfs-progs "btrfs";
  zfsExe = lib.getExe' pkgs.zfs "zfs";
  mountExe = lib.getExe' pkgs.util-linux "mount";
  umountExe = lib.getExe' pkgs.util-linux "umount";

  mkZfsSnapshotName = name: backup: "${backup.preSnapshot.subvolume}@kopia-${name}";

  # Auto-generate a temporary snapshot path.
  # btrfs: must be on the same filesystem, so place as a sibling of the subvolume.
  # ZFS: just a mount point, use an ephemeral path under /run.
  mkSnapshotPath =
    name: backup:
    if backup.preSnapshot.type == "btrfs" then
      "${builtins.dirOf backup.preSnapshot.subvolume}/.kopia-snapshot-${name}"
    else
      "/run/kopia-snapshot/${name}";

  mkPreSnapshotScript =
    name: backup:
    let
      snapshotPath = mkSnapshotPath name backup;
      subvolume = lib.escapeShellArg backup.preSnapshot.subvolume;
      escapedSnapshotPath = lib.escapeShellArg snapshotPath;
    in
    if !backup.preSnapshot.enable then
      ""
    else if backup.preSnapshot.type == "btrfs" then
      ''
        # Clean up any leftover snapshot (recursive to handle nested subvols)
        if ${btrfsExe} subvolume show ${escapedSnapshotPath} &>/dev/null; then
          ${btrfsExe} subvolume delete -R ${escapedSnapshotPath}
        fi

        # Create a writable snapshot of the top-level subvolume.
        # Writable because we need to replace empty stubs for nested subvolumes.
        ${btrfsExe} subvolume snapshot \
          ${subvolume} \
          ${escapedSnapshotPath}

        # Recursively snapshot nested subvolumes.
        # btrfs subvolume list -o lists subvolumes below the given path with
        # btrfs-internal paths (relative to filesystem root). We strip the
        # source subvolume's prefix to get paths relative to the subvolume.
        src_btrfs_path=$(${btrfsExe} subvolume show ${subvolume} | head -1 | xargs)
        ${btrfsExe} subvolume list -o ${subvolume} | awk '{print $NF}' | while IFS= read -r nested_path; do
          rel="''${nested_path#"$src_btrfs_path"/}"
          src="${lib.strings.removeSuffix "/" (lib.escapeShellArg backup.preSnapshot.subvolume)}/$rel"
          dst="${lib.strings.removeSuffix "/" (lib.escapeShellArg snapshotPath)}/$rel"
          # Remove the empty stub directory left by the parent snapshot
          rm -df "$dst" 2>/dev/null || true
          # Create a read-only snapshot of the nested subvolume
          ${btrfsExe} subvolume snapshot -r "$src" "$dst"
        done
      ''
    else
      let
        zfsSnapshotName = lib.escapeShellArg (mkZfsSnapshotName name backup);
      in
      ''
        if ${zfsExe} list -t snapshot ${zfsSnapshotName} &>/dev/null; then
          ${umountExe} ${lib.escapeShellArg snapshotPath} 2>/dev/null || true
          ${zfsExe} destroy ${zfsSnapshotName}
        fi
        ${zfsExe} snapshot ${zfsSnapshotName}
        mkdir -p ${lib.escapeShellArg snapshotPath}
        ${mountExe} -t zfs \
          ${zfsSnapshotName} \
          ${lib.escapeShellArg snapshotPath}
      '';

  mkPostSnapshotScript =
    name: backup: path:
    let
      snapshotPath = mkSnapshotPath name backup;
    in
    if !backup.preSnapshot.enable then
      ""
    else
      let
        # Kopia records snapshots by source path. Since we backed up from
        # the temporary snapshot mount (snapshotPath) rather than the real
        # path, move-history reassociates the snapshot history to the
        # original path so that retention policies and UI display work
        # correctly.
        moveHistory = ''
          ${lib.getExe cfg.package} snapshot move-history \
            ${lib.escapeShellArg snapshotPath} \
            ${lib.escapeShellArg path} || true
        '';
        cleanup =
          if backup.preSnapshot.type == "btrfs" then
            ''
              ${btrfsExe} subvolume delete -R ${lib.escapeShellArg snapshotPath}
            ''
          else
            ''
              ${umountExe} ${lib.escapeShellArg snapshotPath}
              ${zfsExe} destroy ${lib.escapeShellArg (mkZfsSnapshotName name backup)}
            '';
      in
      moveHistory + cleanup;
in
{
  options.services.kopia.backups = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule (
        { ... }:
        {
          options = {
            paths = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = ''
                Paths to back up with Kopia snapshots.
              '';
              example = [
                "/home"
                "/var/lib/postgresql"
              ];
            };

            extraSnapshotArgs = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = ''
                Extra arguments passed to `kopia snapshot create`.
              '';
            };

            preSnapshot = {
              enable = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = ''
                  Whether to create a filesystem snapshot (btrfs/zfs) before
                  the kopia backup, for consistency.

                  Note: for btrfs with nested subvolumes, each subvolume is
                  snapshotted separately, so the overall snapshot is NOT atomic.
                  ZFS snapshots of a single dataset are atomic.
                '';
              };

              type = lib.mkOption {
                type = lib.types.enum [
                  "btrfs"
                  "zfs"
                ];
                default = "btrfs";
                description = ''
                  Type of filesystem snapshot to create.
                '';
              };

              subvolume = lib.mkOption {
                type = with lib.types; nullOr str;
                default = null;
                description = ''
                  Btrfs subvolume path or ZFS dataset name to snapshot.
                '';
              };
            };

            backupPrepareCommand = lib.mkOption {
              type = with lib.types; nullOr str;
              default = null;
              description = ''
                A script that must run before starting the backup process.
              '';
            };

            backupCleanupCommand = lib.mkOption {
              type = with lib.types; nullOr str;
              default = null;
              description = ''
                A script that must run after finishing the backup process.
                This runs in ExecStopPost, so it executes even if the backup fails.
              '';
            };

            nice = lib.mkOption {
              type = lib.types.ints.between (-20) 19;
              default = 19;
              description = ''
                Niceness value for the backup service process.
                See {manpage}`nice(1)`.
              '';
            };

            ioSchedulingClass = lib.mkOption {
              type = lib.types.enum [
                "idle"
                "best-effort"
                "realtime"
                "none"
              ];
              default = "idle";
              description = ''
                I/O scheduling class for the backup service (see {manpage}`ionice(1)`).
                Note that this only takes effect with the CFQ I/O scheduler.
                NVMe drives typically use mq-deadline or none, which do not
                honor this setting. Use {option}`ioWeight` instead on such
                systems.
                Set to `"none"` to leave unset.
              '';
            };

            ioWeight = lib.mkOption {
              type = with lib.types; nullOr (ints.between 1 10000);
              default = 10;
              description = ''
                cgroup v2 I/O weight for the backup service (1–10000, default 100).
                Lower values mean lower I/O priority. This works with modern I/O
                schedulers (mq-deadline, bfq, none) where {option}`ioSchedulingClass`
                has no effect.
                Set to `null` to leave unset.
              '';
            };
          };
        }
      )
    );
  };

  config = lib.mkIf (cfg.backups != { }) {
    assertions = lib.flatten (
      lib.mapAttrsToList (name: backup: [
        {
          assertion = backup.preSnapshot.enable -> backup.preSnapshot.subvolume != null;
          message = "services.kopia.backups.${name}: preSnapshot.subvolume must be set when preSnapshot.enable is true";
        }
        {
          assertion = backup.preSnapshot.enable -> lib.length backup.paths == 1;
          message = "services.kopia.backups.${name}: exactly one path must be set when preSnapshot.enable is true";
        }
      ]) cfg.backups
    );

    systemd.services = lib.mapAttrs' (
      name: backup:
      let
        kopiaExe = lib.getExe cfg.package;
        extraArgs = lib.concatStringsSep " " (map lib.escapeShellArg backup.extraSnapshotArgs);
        snapshotScript = pkgs.writeShellScript "kopia-snapshot-${name}" ''
          set -euo pipefail
          export KOPIA_PASSWORD="$(cat ${lib.escapeShellArg backup.passwordFile})"

          ${lib.concatMapStringsSep "\n" (
            path:
            let
              snapshotTarget =
                if backup.preSnapshot.enable then
                  lib.escapeShellArg (mkSnapshotPath name backup)
                else
                  lib.escapeShellArg path;
            in
            ''
              ${kopiaExe} snapshot create ${snapshotTarget} ${extraArgs}
              ${mkPostSnapshotScript name backup path}
            ''
          ) backup.paths}
        '';
      in
      lib.nameValuePair (helpers.mkUnitBaseName "snapshot" name) (
        let
          baseServiceConfig = helpers.mkBaseServiceConfig name backup;
        in
        {
          description = "Kopia snapshot for ${name}";
          requires = [ (helpers.mkUnitQualifiedName "repository" name) ];
          after = [ (helpers.mkUnitQualifiedName "repository" name) ];
          environment = helpers.mkKopiaEnvironment name;
          restartIfChanged = false;
          serviceConfig = baseServiceConfig // {
            Nice = backup.nice;
            ExecStart = snapshotScript;
          }
          // lib.optionalAttrs (backup.ioSchedulingClass != "none") {
            IOSchedulingClass = backup.ioSchedulingClass;
          }
          // lib.optionalAttrs (backup.ioWeight != null) {
            IOWeight = backup.ioWeight;
          }
          // lib.optionalAttrs backup.preSnapshot.enable {
            ReadWritePaths =
              baseServiceConfig.ReadWritePaths
              ++ [ (builtins.dirOf backup.preSnapshot.subvolume) ]
              ++ backup.paths;
          };
        }
        // lib.optionalAttrs (backup.preSnapshot.enable || backup.backupPrepareCommand != null) {
          preStart = ''
            ${lib.optionalString (backup.backupPrepareCommand != null) (
              toString (pkgs.writeScript "kopia-backup-prepare-${name}" backup.backupPrepareCommand)
            )}
            ${mkPreSnapshotScript name backup}
          '';
        }
        // lib.optionalAttrs (backup.backupCleanupCommand != null) {
          postStop = toString (pkgs.writeScript "kopia-backup-cleanup-${name}" backup.backupCleanupCommand);
        }
      )
    ) (lib.filterAttrs (_: b: b.paths != [ ]) cfg.backups);
  };
}
