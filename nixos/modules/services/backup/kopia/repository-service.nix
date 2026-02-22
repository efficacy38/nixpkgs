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
    else
      throw "mkRepositoryArgs: unsupported repository type: ${backup.repositoryType}";
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

              accessKeyId = lib.mkOption {
                type = with lib.types; nullOr str;
                default = null;
                description = ''
                  AWS access key ID for S3 authentication.
                  Mutually exclusive with {option}`s3.accessKeyIdFile`.

                  ::: {.warning}
                  This value will be stored in the Nix store in plain text.
                  Prefer {option}`s3.accessKeyIdFile` instead.
                  :::
                '';
              };

              accessKeyIdFile = lib.mkOption {
                type = with lib.types; nullOr str;
                default = null;
                description = ''
                  Path to a file containing the AWS access key ID.
                  Read at runtime for secrets management.
                  Mutually exclusive with {option}`s3.accessKeyId`.
                '';
              };

              secretAccessKey = lib.mkOption {
                type = with lib.types; nullOr str;
                default = null;
                description = ''
                  AWS secret access key for S3 authentication.
                  Mutually exclusive with {option}`s3.secretAccessKeyFile`.

                  ::: {.warning}
                  This value will be stored in the Nix store in plain text.
                  Prefer {option}`s3.secretAccessKeyFile` instead.
                  :::
                '';
              };

              secretAccessKeyFile = lib.mkOption {
                type = with lib.types; nullOr str;
                default = null;
                description = ''
                  Path to a file containing the AWS secret access key.
                  Read at runtime for secrets management.
                  Mutually exclusive with {option}`s3.secretAccessKey`.
                '';
              };

              sessionToken = lib.mkOption {
                type = with lib.types; nullOr str;
                default = null;
                description = ''
                  AWS session token for temporary credentials.
                  Mutually exclusive with {option}`s3.sessionTokenFile`.

                  ::: {.warning}
                  This value will be stored in the Nix store in plain text.
                  Prefer {option}`s3.sessionTokenFile` instead.
                  :::
                '';
              };

              sessionTokenFile = lib.mkOption {
                type = with lib.types; nullOr str;
                default = null;
                description = ''
                  Path to a file containing the AWS session token.
                  Read at runtime for secrets management.
                  Mutually exclusive with {option}`s3.sessionToken`.
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
      lib.mapAttrsToList (
        name: backup:
        let
          prefix = "services.kopia.backups.${name}";
          isS3 = backup.repositoryType == "s3";
          isSftp = backup.repositoryType == "sftp";
          isWebdav = backup.repositoryType == "webdav";
        in
        [
          {
            assertion = backup.repositoryType == "filesystem" -> backup.repositoryPath != null;
            message = "${prefix}: repositoryPath must be set when repositoryType is \"filesystem\"";
          }
          {
            assertion = isS3 -> backup.s3.bucket != null;
            message = "${prefix}: s3.bucket must be set when repositoryType is \"s3\"";
          }
          {
            assertion = isS3 -> (backup.s3.accessKeyId != null || backup.s3.accessKeyIdFile != null);
            message = "${prefix}: one of s3.accessKeyId or s3.accessKeyIdFile must be set when repositoryType is \"s3\"";
          }
          (helpers.mkMutualExclusionAssertion {
            inherit name;
            optionA = "s3.accessKeyId";
            optionB = "s3.accessKeyIdFile";
            valueA = backup.s3.accessKeyId;
            valueB = backup.s3.accessKeyIdFile;
          })
          {
            assertion = isS3 -> (backup.s3.secretAccessKey != null || backup.s3.secretAccessKeyFile != null);
            message = "${prefix}: one of s3.secretAccessKey or s3.secretAccessKeyFile must be set when repositoryType is \"s3\"";
          }
          (helpers.mkMutualExclusionAssertion {
            inherit name;
            optionA = "s3.secretAccessKey";
            optionB = "s3.secretAccessKeyFile";
            valueA = backup.s3.secretAccessKey;
            valueB = backup.s3.secretAccessKeyFile;
          })
          (helpers.mkMutualExclusionAssertion {
            inherit name;
            optionA = "s3.sessionToken";
            optionB = "s3.sessionTokenFile";
            valueA = backup.s3.sessionToken;
            valueB = backup.s3.sessionTokenFile;
          })
          {
            assertion = isSftp -> (backup.sftp.host != null || backup.sftp.hostFile != null);
            message = "${prefix}: one of sftp.host or sftp.hostFile must be set when repositoryType is \"sftp\"";
          }
          (helpers.mkMutualExclusionAssertion {
            inherit name;
            optionA = "sftp.host";
            optionB = "sftp.hostFile";
            valueA = backup.sftp.host;
            valueB = backup.sftp.hostFile;
          })
          {
            assertion = isSftp -> backup.sftp.username != null;
            message = "${prefix}: sftp.username must be set when repositoryType is \"sftp\"";
          }
          {
            assertion = isSftp -> backup.sftp.path != null;
            message = "${prefix}: sftp.path must be set when repositoryType is \"sftp\"";
          }
          {
            assertion =
              isSftp
              -> (
                backup.sftp.keyFile != null || backup.sftp.password != null || backup.sftp.passwordFile != null
              );
            message = "${prefix}: at least one of sftp.keyFile, sftp.password, or sftp.passwordFile must be set when repositoryType is \"sftp\"";
          }
          (helpers.mkMutualExclusionAssertion {
            inherit name;
            optionA = "sftp.password";
            optionB = "sftp.passwordFile";
            valueA = backup.sftp.password;
            valueB = backup.sftp.passwordFile;
          })
          {
            assertion = isWebdav -> (backup.webdav.url != null || backup.webdav.urlFile != null);
            message = "${prefix}: one of webdav.url or webdav.urlFile must be set when repositoryType is \"webdav\"";
          }
          (helpers.mkMutualExclusionAssertion {
            inherit name;
            optionA = "webdav.url";
            optionB = "webdav.urlFile";
            valueA = backup.webdav.url;
            valueB = backup.webdav.urlFile;
          })
          (helpers.mkMutualExclusionAssertion {
            inherit name;
            optionA = "webdav.username";
            optionB = "webdav.usernameFile";
            valueA = backup.webdav.username;
            valueB = backup.webdav.usernameFile;
          })
          (helpers.mkMutualExclusionAssertion {
            inherit name;
            optionA = "webdav.password";
            optionB = "webdav.passwordFile";
            valueA = backup.webdav.password;
            valueB = backup.webdav.passwordFile;
          })
        ]
      ) cfg.backups
    );

    warnings = lib.flatten (
      lib.mapAttrsToList (
        name: backup:
        helpers.mkPlainTextWarning {
          inherit name;
          option = "s3.accessKeyId";
          value = backup.s3.accessKeyId;
          fileOption = "s3.accessKeyIdFile";
        }
        ++ helpers.mkPlainTextWarning {
          inherit name;
          option = "s3.secretAccessKey";
          value = backup.s3.secretAccessKey;
          fileOption = "s3.secretAccessKeyFile";
        }
        ++ helpers.mkPlainTextWarning {
          inherit name;
          option = "s3.sessionToken";
          value = backup.s3.sessionToken;
          fileOption = "s3.sessionTokenFile";
        }
        ++ helpers.mkPlainTextWarning {
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
                export KOPIA_WEBDAV_USERNAME=${lib.escapeShellArg dav.username}
              ''}
              ${lib.optionalString (dav.usernameFile != null) ''
                export KOPIA_WEBDAV_USERNAME="$(cat ${lib.escapeShellArg dav.usernameFile})"
              ''}
              ${lib.optionalString (dav.password != null) ''
                export KOPIA_WEBDAV_PASSWORD=${lib.escapeShellArg dav.password}
              ''}
              ${lib.optionalString (dav.passwordFile != null) ''
                export KOPIA_WEBDAV_PASSWORD="$(cat ${lib.escapeShellArg dav.passwordFile})"
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
          else if backup.repositoryType == "s3" then
            let
              s3 = backup.s3;
            in
            pkgs.writeShellScript "kopia-repository-connect-${name}" ''
              set -euo pipefail
              export KOPIA_PASSWORD="$(cat ${lib.escapeShellArg backup.passwordFile})"

              ${
                if s3.accessKeyId != null then
                  "export AWS_ACCESS_KEY_ID=${lib.escapeShellArg s3.accessKeyId}"
                else
                  ''export AWS_ACCESS_KEY_ID="$(cat ${lib.escapeShellArg s3.accessKeyIdFile})"''
              }
              ${
                if s3.secretAccessKey != null then
                  "export AWS_SECRET_ACCESS_KEY=${lib.escapeShellArg s3.secretAccessKey}"
                else
                  ''export AWS_SECRET_ACCESS_KEY="$(cat ${lib.escapeShellArg s3.secretAccessKeyFile})"''
              }
              ${lib.optionalString (s3.sessionToken != null) ''
                export AWS_SESSION_TOKEN=${lib.escapeShellArg s3.sessionToken}
              ''}
              ${lib.optionalString (s3.sessionTokenFile != null) ''
                export AWS_SESSION_TOKEN="$(cat ${lib.escapeShellArg s3.sessionTokenFile})"
              ''}
              S3_ARGS="--bucket ${lib.escapeShellArg s3.bucket} --endpoint ${lib.escapeShellArg s3.endpoint} --region ${lib.escapeShellArg s3.region}"
              ${lib.optionalString s3.disableTLS ''
                S3_ARGS="$S3_ARGS --disable-tls"
              ''}

              if ! ${kopiaExe} repository connect s3 $S3_ARGS; then
                ${kopiaExe} repository create s3 $S3_ARGS
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
