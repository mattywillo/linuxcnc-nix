{ fetchurl, stdenv, ncurses, lib }:
stdenv.mkDerivation rec {
  pname = "readline";
  version = "5.2";

  src = fetchurl {
    url = "mirror://gnu/readline/readline-${version}.tar.gz";
    sha256 = "0icz4hqqq8mlkwrpczyaha94kns0am9z0mh3a2913kg2msb8vs0j";
  };

  propagatedBuildInputs = [ncurses];

  patches = [ ./gnu_patches.patch ];

  meta = with lib; {
    branch = "5";
    platforms = platforms.unix;
    license = licenses.gpl2;
  };
}
