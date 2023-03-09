{ lib
, stdenv
, fetchFromGitHub
, cmake
, python3
, boost
}:

stdenv.mkDerivation rec {
  pname = "cryptominisat";
  version = "5.11.4";

  src = fetchFromGitHub {
    owner = "msoos";
    repo = "cryptominisat";
    rev = version;
    hash = "sha256-7JNfFKSYWgyyNnWNzXGLqWRwSW+5r6PBMelKeAmx8sc=";
  };

  buildInputs = [ python3 boost ];
  nativeBuildInputs = [ cmake ];

  meta = with lib; {
    description = "An advanced SAT Solver";
    homepage = "https://github.com/msoos/cryptominisat";
    license = licenses.mit;
    maintainers = with maintainers; [ mic92 ];
    platforms = platforms.unix;
  };
}
