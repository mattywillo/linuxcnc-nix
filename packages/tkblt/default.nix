{ lib, fetchzip, tcl, tk, xorg }:
tcl.mkTclDerivation rec {
  pname = "tkblt";
  version = "2.5.3";

  src = fetchzip {
    url = "http://deb.debian.org/debian/pool/main/b/blt/blt_2.5.3+dfsg.orig.tar.xz";
    sha256 = "3a9zfTTzOo7HRxAl/6RW8cAxaW/YtnsDb5aV1lyKMVw=";
  };

  patches = [
    ./tcl8.6.patch
    ./tk8.6.patch
    ./install.patch
    ./ldflags.patch
  ];

  meta = {
    homepage = "https://sourceforge.net/projects/wize/";
    description = "BLT for Tcl/Tk with patches from Debian";
    license = lib.licenses.tcltk;
    platforms = lib.platforms.unix;
  };

  buildInputs  = [ tcl tk.dev tk xorg.libX11 xorg.libXext ];

  configureFlags  = [
    "--with-tcl=${tcl}/lib"
    "--with-tk=${tk}/lib"
    "--with-tkincls=${tk.dev}/include"
    "--with-tclincls=${tcl}/include"
    "--x-includes=${xorg.libXext}/include"
    "--x-libraries=${xorg.libX11}/lib"
  ];

  preFixup = ''
    substituteInPlace $out/lib/blt2.5/pkgIndex.tcl --replace 'package ifneeded BLT $version' 'package ifneeded BLT ${version}'
  '';

}
