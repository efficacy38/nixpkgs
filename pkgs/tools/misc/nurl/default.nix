{ lib
, rustPlatform
, fetchFromGitHub
, installShellFiles
, makeWrapper
, gitMinimal
, mercurial
, nix
}:

rustPlatform.buildRustPackage rec {
  pname = "nurl";
  version = "0.3.0";

  src = fetchFromGitHub {
    owner = "nix-community";
    repo = "nurl";
    rev = "v${version}";
    hash = "sha256-jZ+cCp1THDhfHH5yMmRPjGuthOqsgcF/3OjZ61FMdA4=";
  };

  cargoSha256 = "sha256-v/imDpIY/uN8fdrmvCNjQu0iL92cAL+aGZR0YjNaAH8=";

  nativeBuildInputs = [
    installShellFiles
    makeWrapper
  ];

  postInstall = ''
    wrapProgram $out/bin/nurl \
      --prefix PATH : ${lib.makeBinPath [ gitMinimal mercurial nix ]}
    installManPage artifacts/nurl.1
    installShellCompletion artifacts/nurl.{bash,fish} --zsh artifacts/_nurl
  '';

  GEN_ARTIFACTS = "artifacts";

  meta = with lib; {
    description = "Command-line tool to generate Nix fetcher calls from repository URLs";
    homepage = "https://github.com/nix-community/nurl";
    changelog = "https://github.com/nix-community/nurl/blob/v${version}/CHANGELOG.md";
    license = licenses.mpl20;
    maintainers = with maintainers; [ figsoda ];
  };
}
