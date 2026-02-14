{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.kopia;
  helpers = import ./helpers.nix { inherit lib; };

  mkRepositoryArgs =
    backup:
    if backup.repositoryType == "filesystem" then
      [
        "--path"
        (lib.escapeShellArg backup.repositoryPath)
      ]
    else if backup.repositoryType == "s3" then
      [
        "--bucket"
        (lib.escapeShellArg backup.s3.bucket)
        "--endpoint"
        (lib.escapeShellArg backup.s3.endpoint)
        "--region"
        (lib.escapeShellArg backup.s3.region)
      ]
      ++ lib.optional backup.s3.disableTLS "--disable-tls"
    else if backup.repositoryType == "sftp" then
      null # sftp args are constructed at runtime
    else if backup.repositoryType == "webdav" then
      null # webdav args are constructed at runtime
    else
      throw "Unsupported repository type: ${backup.repositoryType}";
in
{
  options.services.kopia.backups = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule (
        { ... }:
        {
          options = {
            repositoryType = lib.mkOption {
              type = lib.types.enum [
                "filesystem"
                "s3"
                "sftp"
                "webdav"
              ];
              description = ''
                Type of repository backend to use.
              '';
              example = "filesystem";
            };

            repositoryPath = lib.mkOption {
              type = with lib.types; nullOr str;
              default = null;
              description = ''
                Path to local filesystem directory for the repository.
                Required when {option}`repositoryType` is `"filesystem"`.
              '';
              example = "/mnt/backup";
            };

            s3 = {
              bucket = lib.mkOption {
                type = with lib.types; nullOr str;
                default = null;
                description = ''
                  S3 bucket name. Required when {option}`repositoryType` is `"s3"`.
                '';
              };

              endpoint = lib.mkOption {
                type = lib.types.str;
                default = "s3.amazonaws.com";
                description = ''
                  S3 endpoint URL.
                '';
              };

              region = lib.mkOption {
                type = lib.types.str;
                default = "us-east-1";
                description = ''
                  S3 region.
                '';
              };

              disableTLS = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = ''
                  Disable TLS for S3 connections.
                '';
              };
            };

            sftp = {
              host = lib.mkOption {
                type = with lib.types; nullOr str;
                default = null;
                description = ''
                  SFTP server hostname.
                  Mutually exclusive with {option}`sftp.hostFile`.
                '';
              };

              hostFile = lib.mkOption {
                type = with lib.types; nullOr str;
                default = null;
                description = ''
                  Path to a file containing the SFTP server hostname.
                  Read at runtime for secrets management.
                  Mutually exclusive with {option}`sftp.host`.
                '';
              };

              port = lib.mkOption {
                type = lib.types.port;
                default = 22;
                description = ''
                  SSH port for the SFTP connection.
                '';
              };

              username = lib.mkOption {
                type = with lib.types; nullOr str;
                default = null;
                description = ''
                  SSH username for the SFTP connection.
                  Required when {option}`repositoryType` is `"sftp"`.
                '';
              };

              path = lib.mkOption {
                type = with lib.types; nullOr str;
                default = null;
                description = ''
                  Remote directory path for the repository on the SFTP server.
                  Required when {option}`repositoryType` is `"sftp"`.
                '';
              };

              keyFile = lib.mkOption {
                type = with lib.types; nullOr str;
                default = null;
                description = ''
                  Path to SSH private key file for authentication.
                  Preferred over password authentication.
                '';
              };

              password = lib.mkOption {
                type = with lib.types; nullOr str;
                default = null;
                description = ''
                  SFTP password for authentication.
                  Mutually exclusive with {option}`sftp.passwordFile`.

                  ::: {.warning}
                  This password will be stored in the Nix store in plain text.
                  Prefer {option}`sftp.passwordFile` or {option}`sftp.keyFile` instead.
                  :::
                '';
              };

              passwordFile = lib.mkOption {
                type = with lib.types; nullOr str;
                default = null;
                description = ''
                  Path to a file containing the SFTP password.
                  Mutually exclusive with {option}`sftp.password`.

                  ::: {.warning}
                  Password authentication is less secure than key-based authentication.
                  Prefer setting {option}`sftp.keyFile` with an SSH private key instead.
                  :::
                '';
              };

              knownHostsFile = lib.mkOption {
                type = with lib.types; nullOr str;
                default = null;
                description = ''
                  Path to SSH known_hosts file for host key verification.
                '';
              };
            };

            webdav = {
              url = lib.mkOption {
                type = with lib.types; nullOr str;
                default = null;
                description = ''
                  WebDAV server URL.
                  Mutually exclusive with {option}`webdav.urlFile`.
                '';
                example = "https://webdav.example.com/backup";
              };

              urlFile = lib.mkOption {
                type = with lib.types; nullOr str;
                default = null;
                description = ''
                  Path to a file containing the WebDAV server URL.
                  Read at runtime for secrets management.
                  Mutually exclusive with {option}`webdav.url`.
                '';
              };

              username = lib.mkOption {
                type = with lib.types; nullOr str;
                default = null;
                description = ''
                  WebDAV username for authentication.
                  Mutually exclusive with {option}`webdav.usernameFile`.
                '';
              };

              usernameFile = lib.mkOption {
                type = with lib.types; nullOr str;
                default = null;
                description = ''
                  Path to a file containing the WebDAV username.
                  Read at runtime for secrets management.
                  Mutually exclusive with {option}`webdav.username`.
                '';
              };

              password = lib.mkOption {
                type = with lib.types; nullOr str;
                default = null;
                description = ''
                  WebDAV password for authentication.
                  Mutually exclusive with {option}`webdav.passwordFile`.

                  ::: {.warning}
                  This password will be stored in the Nix store in plain text.
                  Prefer {option}`webdav.passwordFile` instead.
                  :::
                '';
              };

              passwordFile = lib.mkOption {
                type = with lib.types; nullOr str;
                default = null;
                description = ''
                  Path to a file containing the WebDAV password.
                  Read at runtime for secrets management.
                  Mutually exclusive with {option}`webdav.password`.
                '';
              };

              flat = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = ''
                  Use flat directory structure on the WebDAV server.
                '';
              };

              atomicWrites = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = ''
                  Assume the WebDAV provider implements atomic writes.
                '';
              };
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
          assertion = backup.repositoryType == "filesystem" -> backup.repositoryPath != null;
          message = "services.kopia.backups.${name}: repositoryPath must be set when repositoryType is \"filesystem\"";
        }
        {
          assertion = backup.repositoryType == "s3" -> backup.s3.bucket != null;
          message = "services.kopia.backups.${name}: s3.bucket must be set when repositoryType is \"s3\"";
        }
        {
          assertion = backup.repositoryType == "s3" -> backup.environmentFile != null;
          message = "services.kopia.backups.${name}: environmentFile must be set for s3 (provide AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY)";
        }
        {
          assertion =
            backup.repositoryType == "sftp" -> (backup.sftp.host != null || backup.sftp.hostFile != null);
          message = "services.kopia.backups.${name}: one of sftp.host or sftp.hostFile must be set when repositoryType is \"sftp\"";
        }
        {
          assertion =
            backup.repositoryType == "sftp" -> !(backup.sftp.host != null && backup.sftp.hostFile != null);
          message = "services.kopia.backups.${name}: sftp.host and sftp.hostFile are mutually exclusive";
        }
        {
          assertion = backup.repositoryType == "sftp" -> backup.sftp.username != null;
          message = "services.kopia.backups.${name}: sftp.username must be set when repositoryType is \"sftp\"";
        }
        {
          assertion = backup.repositoryType == "sftp" -> backup.sftp.path != null;
          message = "services.kopia.backups.${name}: sftp.path must be set when repositoryType is \"sftp\"";
        }
        {
          assertion =
            backup.repositoryType == "sftp"
            -> (
              backup.sftp.keyFile != null || backup.sftp.password != null || backup.sftp.passwordFile != null
            );
          message = "services.kopia.backups.${name}: at least one of sftp.keyFile, sftp.password, or sftp.passwordFile must be set when repositoryType is \"sftp\"";
        }
        {
          assertion =
            backup.repositoryType == "sftp"
            -> !(backup.sftp.password != null && backup.sftp.passwordFile != null);
          message = "services.kopia.backups.${name}: sftp.password and sftp.passwordFile are mutually exclusive";
        }
        {
          assertion =
            backup.repositoryType == "webdav" -> (backup.webdav.url != null || backup.webdav.urlFile != null);
          message = "services.kopia.backups.${name}: one of webdav.url or webdav.urlFile must be set when repositoryType is \"webdav\"";
        }
        {
          assertion =
            backup.repositoryType == "webdav" -> !(backup.webdav.url != null && backup.webdav.urlFile != null);
          message = "services.kopia.backups.${name}: webdav.url and webdav.urlFile are mutually exclusive";
        }
        {
          assertion =
            backup.repositoryType == "webdav"
            -> !(backup.webdav.username != null && backup.webdav.usernameFile != null);
          message = "services.kopia.backups.${name}: webdav.username and webdav.usernameFile are mutually exclusive";
        }
        {
          assertion =
            backup.repositoryType == "webdav"
            -> !(backup.webdav.password != null && backup.webdav.passwordFile != null);
          message = "services.kopia.backups.${name}: webdav.password and webdav.passwordFile are mutually exclusive";
        }
      ]) cfg.backups
    );

    warnings = lib.flatten (
      lib.mapAttrsToList (
        name: backup:
        helpers.mkPlainTextWarning {
          inherit name;
          option = "sftp.password";
          value = backup.sftp.password;
          fileOption = "sftp.passwordFile";
        }
        ++ helpers.mkPlainTextWarning {
          inherit name;
          option = "webdav.password";
          value = backup.webdav.password;
          fileOption = "webdav.passwordFile";
        }
      ) cfg.backups
    );

    systemd.services = lib.mapAttrs' (
      name: backup:
      let
        kopiaExe = lib.getExe cfg.package;
        needsNetwork = builtins.elem backup.repositoryType [
          "s3"
          "sftp"
          "webdav"
        ];
        startScript =
          if backup.repositoryType == "webdav" then
            let
              dav = backup.webdav;
            in
            pkgs.writeShellScript "kopia-repository-connect-${name}" ''
              set -euo pipefail
              export KOPIA_PASSWORD="$(cat ${lib.escapeShellArg backup.passwordFile})"

              ${
                if dav.url != null then
                  "WEBDAV_URL=${lib.escapeShellArg dav.url}"
                else
                  ''WEBDAV_URL="$(cat ${lib.escapeShellArg dav.urlFile})"''
              }
              WEBDAV_ARGS="--url $WEBDAV_URL"
              ${lib.optionalString dav.flat ''
                WEBDAV_ARGS="$WEBDAV_ARGS --flat"
              ''}
              ${lib.optionalString dav.atomicWrites ''
                WEBDAV_ARGS="$WEBDAV_ARGS --atomic-writes"
              ''}
              ${lib.optionalString (dav.username != null) ''
                WEBDAV_ARGS="$WEBDAV_ARGS --webdav-username ${lib.escapeShellArg dav.username}"
              ''}
              ${lib.optionalString (dav.usernameFile != null) ''
                WEBDAV_ARGS="$WEBDAV_ARGS --webdav-username $(cat ${lib.escapeShellArg dav.usernameFile})"
              ''}
              ${lib.optionalString (dav.password != null) ''
                WEBDAV_ARGS="$WEBDAV_ARGS --webdav-password ${lib.escapeShellArg dav.password}"
              ''}
              ${lib.optionalString (dav.passwordFile != null) ''
                WEBDAV_ARGS="$WEBDAV_ARGS --webdav-password $(cat ${lib.escapeShellArg dav.passwordFile})"
              ''}

              if ! ${kopiaExe} repository connect webdav $WEBDAV_ARGS; then
                ${kopiaExe} repository create webdav $WEBDAV_ARGS
              fi
            ''
          else if backup.repositoryType == "sftp" then
            let
              sftp = backup.sftp;
            in
            pkgs.writeShellScript "kopia-repository-connect-${name}" ''
              set -euo pipefail
              export KOPIA_PASSWORD="$(cat ${lib.escapeShellArg backup.passwordFile})"

              ${
                if sftp.host != null then
                  "SFTP_HOST=${lib.escapeShellArg sftp.host}"
                else
                  ''SFTP_HOST="$(cat ${lib.escapeShellArg sftp.hostFile})"''
              }
              SFTP_ARGS="--path ${lib.escapeShellArg sftp.path} --host $SFTP_HOST --port ${toString sftp.port} --username ${lib.escapeShellArg sftp.username}"
              ${lib.optionalString (sftp.keyFile != null) ''
                SFTP_ARGS="$SFTP_ARGS --keyfile ${lib.escapeShellArg sftp.keyFile}"
              ''}
              ${lib.optionalString (sftp.knownHostsFile != null) ''
                SFTP_ARGS="$SFTP_ARGS --known-hosts ${lib.escapeShellArg sftp.knownHostsFile}"
              ''}
              ${lib.optionalString (sftp.password != null) ''
                SFTP_ARGS="$SFTP_ARGS --sftp-password ${lib.escapeShellArg sftp.password}"
              ''}
              ${lib.optionalString (sftp.passwordFile != null) ''
                SFTP_ARGS="$SFTP_ARGS --sftp-password $(cat ${lib.escapeShellArg sftp.passwordFile})"
              ''}

              if ! ${kopiaExe} repository connect sftp $SFTP_ARGS; then
                ${kopiaExe} repository create sftp $SFTP_ARGS
              fi
            ''
          else
            let
              repoArgs = lib.concatStringsSep " " (mkRepositoryArgs backup);
            in
            pkgs.writeShellScript "kopia-repository-connect-${name}" ''
              set -euo pipefail
              export KOPIA_PASSWORD="$(cat ${lib.escapeShellArg backup.passwordFile})"

              if ! ${kopiaExe} repository connect ${backup.repositoryType} ${repoArgs}; then
                ${kopiaExe} repository create ${backup.repositoryType} ${repoArgs}
              fi
            '';
      in
      lib.nameValuePair (helpers.mkUnitBaseName "repository" name) {
        description = "Kopia repository connection for ${name}";
        restartIfChanged = false;
        wants = lib.optional needsNetwork "network-online.target";
        after = lib.optional needsNetwork "network-online.target";
        environment = helpers.mkKopiaEnvironment name;
        serviceConfig = helpers.mkBaseServiceConfig name backup // {
          RemainAfterExit = true;
          ExecStart = startScript;
          ExecStop = "${kopiaExe} repository disconnect";
        };
      }
    ) cfg.backups;
  };
}
