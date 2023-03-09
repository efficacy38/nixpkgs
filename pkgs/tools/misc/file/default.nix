{ lib, stdenv, fetchurl, file, zlib, libgnurx }:

# Note: this package is used for bootstrapping fetchurl, and thus
# cannot use fetchpatch! All mutable patches (generated by GitHub or
# cgit) that are needed here should be included directly in Nixpkgs as
# files.

stdenv.mkDerivation rec {
  pname = "file";
  version = "5.44";

  src = fetchurl {
    urls = [
      "https://astron.com/pub/file/${pname}-${version}.tar.gz"
      "https://distfiles.macports.org/file/${pname}-${version}.tar.gz"
    ];
    sha256 = "sha256-N1HH+6jbyDHLjXzIr/IQNUWbjOUVXviwiAon0ChHXzs=";
  };

  patches = [
    # Backport fix to identification for pyzip files.
    # Needed for strip-nondeterminism.
    # https://salsa.debian.org/reproducible-builds/strip-nondeterminism/-/issues/20
    ./pyzip.patch

    # Backport fix for --uncompress always detecting contents as "empty"
    (fetchurl {
      url = "https://gitweb.gentoo.org/repo/gentoo.git/plain/sys-apps/file/files/file-5.44-decompress-empty.patch?h=dfc57da515a2aaf085bea68267cc727f1bfaa691";
      hash = "sha256-fUzRQAlLWczBmR5iA1Gk66mHjP40MJcMdgCtm2+u1SQ=";
    })
  ];

  strictDeps = true;
  enableParallelBuilding = true;

  nativeBuildInputs = lib.optional (stdenv.hostPlatform != stdenv.buildPlatform) file;
  buildInputs = [ zlib ]
    ++ lib.optional stdenv.hostPlatform.isWindows libgnurx;

  # https://bugs.astron.com/view.php?id=382
  doCheck = !stdenv.buildPlatform.isMusl;

  makeFlags = lib.optional stdenv.hostPlatform.isWindows "FILE_COMPILE=file";

  meta = with lib; {
    homepage = "https://darwinsys.com/file";
    description = "A program that shows the type of files";
    maintainers = with maintainers; [ doronbehar ];
    license = licenses.bsd2;
    platforms = platforms.all;
  };
}
