{ stdenv, fetchurl, zlib }:

stdenv.mkDerivation rec {
  version = "1.17.1";
  name = "clp-${version}";
  src = fetchurl {
    url = "https://www.coin-or.org/download/source/Clp/Clp-${version}.tgz";
    sha256 = "1wdg820g3iikf9344ijwsc8sy6c0m6im42bzzizm6rlmkvnmxhk9";
  };

  propagatedBuildInputs = [ zlib ];

  doCheck = true;

  meta = {
    license = stdenv.lib.licenses.epl10;
    homepage = https://projects.coin-or.org/Clp;
    description = "An open-source linear programming solver written in C++";
    platforms = stdenv.lib.platforms.all;
    maintainers = [ stdenv.lib.maintainers.vbgl ];
  };
}
