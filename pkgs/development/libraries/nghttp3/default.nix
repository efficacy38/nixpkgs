{ lib, stdenv, fetchFromGitHub
, autoreconfHook, pkg-config, file
, cunit, ncurses
, curlHTTP3
}:

stdenv.mkDerivation rec {
  pname = "nghttp3";
  version = "0.9.0";

  src = fetchFromGitHub {
    owner = "ngtcp2";
    repo = pname;
    rev = "v${version}";
    sha256 = "sha256-N4wgk21D1I0tNrKoTGWBtq3neeamCI8axQnFxdT1Txg=";
  };

  outputs = [ "out" "dev" "doc" ];

  nativeBuildInputs = [ autoreconfHook pkg-config file ];
  nativeCheckInputs = [ cunit ncurses ];

  preConfigure = ''
    substituteInPlace ./configure --replace /usr/bin/file ${file}/bin/file
  '';

  doCheck = true;
  enableParallelBuilding = true;

  passthru.tests = {
    inherit curlHTTP3;
  };

  meta = with lib; {
    homepage = "https://github.com/ngtcp2/nghttp3";
    description = "nghttp3 is an implementation of HTTP/3 mapping over QUIC and QPACK in C.";
    license = licenses.mit;
    platforms = platforms.unix;
    maintainers = with maintainers; [ izorkin ];
  };
}
