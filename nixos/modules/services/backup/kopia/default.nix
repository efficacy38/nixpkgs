{
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./repository-service.nix
    ./policy-service.nix
    ./snapshot-service.nix
    ./web-service.nix
  ];

  options.services.kopia.package = lib.mkPackageOption pkgs "kopia" { };

  options.services.kopia.backups = lib.mkOption {
    description = ''
      Periodic backups to create with Kopia.
    '';
    type = lib.types.attrsOf (
      lib.types.submodule (
        { ... }:
        {
          options = {
            passwordFile = lib.mkOption {
              type = lib.types.str;
              description = ''
                Path to a file containing the repository password (KOPIA_PASSWORD).
              '';
              example = "/run/secrets/kopia-password";
            };

            user = lib.mkOption {
              type = lib.types.str;
              default = "root";
              description = ''
                As which user the backup should run.
              '';
            };

          };
        }
      )
    );
    default = { };
    example = lib.literalExpression ''
      {
        # Simple filesystem backup without pre-snapshots.
        localbackup = {
          repository.filesystem.path = "/mnt/backup";
          passwordFile = "/run/secrets/kopia-password";
          paths = [ "/home" "/var/lib/postgresql" ];
          policy.retention.keepDaily = 7;
          policy.retention.keepWeekly = 4;
          policy.compression = "zstd";
        };

        # Btrfs example: creates a read-only btrfs snapshot before backup for
        # point-in-time consistency, then cleans it up afterwards.
        # Enabling preSnapshot is optional but recommended for btrfs users to
        # avoid backing up files in an inconsistent state.
        btrfs-backup = {
          repository.filesystem.path = "/mnt/backup";
          passwordFile = "/run/secrets/kopia-password";
          # NOTE: when using preSnapshot, the path being backed up must reside
          # on a btrfs subvolume. A regular directory on btrfs cannot be
          # snapshotted — only subvolumes can.
          paths = [ "/home" ];
          # Optional but recommended: take a btrfs snapshot before backup.
          # The snapshot is created as a sibling of the subvolume
          # (e.g. /home -> /.kopia-snapshot-btrfs-backup) and removed after backup.
          preSnapshot.enable = true;
          preSnapshot.type = "btrfs";
          # subvolume: the btrfs subvolume path to snapshot.
          # This must point to an actual btrfs subvolume (verify with
          # `btrfs subvolume show /home`), not a regular directory.
          # If preSnapshot.enable is false, this field is ignored.
          preSnapshot.subvolume = "/home";
          policy.retention.keepDaily = 7;
          policy.retention.keepWeekly = 4;
          policy.compression = "zstd";
        };

        # ZFS example: creates a ZFS snapshot and mounts it before backup for
        # point-in-time consistency, then destroys the snapshot afterwards.
        # Enabling preSnapshot is optional but recommended for ZFS users to
        # avoid backing up files in an inconsistent state.
        zfs-backup = {
          repository.s3 = {
            bucket = "my-kopia-backup";
            # endpoint defaults to "s3.amazonaws.com" and can be omitted for AWS.
            # region defaults to "us-east-1" and can be omitted if that is your region.
            accessKeyIdFile = "/run/secrets/aws-access-key-id";
            secretAccessKeyFile = "/run/secrets/aws-secret-access-key";
          };
          passwordFile = "/run/secrets/kopia-password";
          # NOTE: when using preSnapshot, the path being backed up must be the
          # mount point of a ZFS dataset. A subdirectory within a dataset cannot
          # be snapshotted — only datasets can.
          paths = [ "/tank/data" ];
          # Optional but recommended: take a ZFS snapshot before backup.
          # The snapshot is mounted at /run/kopia-snapshot/<name> during backup
          # and destroyed after backup completes.
          preSnapshot.enable = true;
          preSnapshot.type = "zfs";
          # subvolume: the ZFS dataset name (not a file path) to snapshot.
          # This must be a valid ZFS dataset (verify with `zfs list tank/data`),
          # not a child directory within a dataset.
          # If preSnapshot.enable is false, this field is ignored.
          preSnapshot.subvolume = "tank/data";
          policy.retention.keepDaily = 7;
          policy.retention.keepWeekly = 4;
          policy.retention.keepMonthly = 6;
          policy.compression = "zstd";
        };

        # SFTP example: backs up to a remote server over SSH/SFTP.
        # Key-based authentication is preferred for security.
        sftp-backup = {
          repository.sftp = {
            # Use host for a plain hostname, or hostFile to read it from a file
            # at runtime (e.g. for secrets management). They are mutually exclusive.
            host = "backup.example.com";
            path = "/backup/kopia-repo";
            username = "kopia";
            keyFile = "/root/.ssh/id_ed25519";
            knownHostsFile = "/root/.ssh/known_hosts";
          };
          passwordFile = "/run/secrets/kopia-password";
          paths = [ "/home" "/var/lib" ];
          policy.retention.keepDaily = 7;
          policy.retention.keepWeekly = 4;
          policy.compression = "zstd";
        };

        # WebDAV example: backs up to a WebDAV server.
        webdav-backup = {
          repository.webdav = {
            url = "https://webdav.example.com/backup/kopia";
            # Use passwordFile to read credentials from a file at runtime.
            usernameFile = "/run/secrets/webdav-username";
            passwordFile = "/run/secrets/webdav-password";
          };
          passwordFile = "/run/secrets/kopia-password";
          paths = [ "/home" ];
          policy.retention.keepDaily = 7;
          policy.compression = "zstd";
        };
      }
    '';
  };
}
