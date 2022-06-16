{ lib, stdenv, autoreconfHook, wrapGAppsHook, qt5, makeWrapper, fetchFromGitHub, libtool, pkgconfig,
  readline_5, ncurses, libtirpc, systemd, libmodbus, libusb, glib, gtk2, gtk3, procps, kmod, sysctl,
  util-linux, psmisc, intltool, tcl, tk, bwidget, tkimg, tclx, tkblt, pango, cairo, boost, espeak, gst_all_1,
  python3Full, yapps, gobject-introspection, libGLU, xorg, libepoxy, hicolor-icon-theme, glxinfo, bash
}:
let
  pythonPkg = (python3Full.withPackages (ps: [
    yapps
    ps.pyopengl
    ps.pygobject3
    ps.pycairo
    ps.boost
    ps.numpy
    ps.pyqtwebengine
    ps.pyqt5
    ps.opencv4
    ps.gst-python
    ps.xlib
    ps.qscintilla
  ]));
  boost_python = (boost.override { enablePython = true; python = pythonPkg; });
in
stdenv.mkDerivation rec {
  hardeningDisable = [ "all" ];
  enableParalellBuilding = true;
  pname = "linuxcnc";
  version = "2.9-git";
  name = "${pname}-${version}";

  src = fetchFromGitHub {
    owner = "LinuxCNC";
    repo = "linuxcnc";
    rev = "f77537cd4d4dc6191d4bb981e0e1c9d897039fc6";
    sha256 = "05kuTx2J7wdrcoUQ8Tengb0ohXAeGjZV9g9XriWgQL4=";
  };

  nativeBuildInputs = [
    autoreconfHook
    makeWrapper
    wrapGAppsHook
    qt5.wrapQtAppsHook
    gobject-introspection
  ];

  dontWrapGApps = true;
  dontWrapQtApps = true;

  buildInputs = [
    libtool pkgconfig libtirpc systemd libmodbus libusb glib gtk2 gtk3 procps kmod sysctl util-linux
    psmisc intltool tcl tk bwidget tkimg tclx tkblt pango cairo pythonPkg.pkgs.pygobject3 gobject-introspection
    boost_python pythonPkg.pkgs.boost pythonPkg qt5.qtbase espeak gst_all_1.gstreamer
    ncurses readline_5 libGLU xorg.libXmu libepoxy hicolor-icon-theme glxinfo
  ];

  preAutoreconf = ''
    # cd into ./src here instead of setting sourceRoot as the build process uses the original sourceRoot
    cd ./src

    # make halcmd search for setuid apps on PATH, to find setuid wrappers
    substituteInPlace hal/utils/halcmd_commands.c --replace 'EMC2_BIN_DIR "/' '"'
  '';

  patches = [
    ./fix_make.patch          # Some lines don't respect --prefix
    ./pncconf_paths.patch     # Corrects a search path in pncconf
    ./rtapi_app_setuid.patch  # Remove hard coded checks for setuid from rtapi_app
  ];

  postAutoreconf = ''
    # We need -lncurses for -lreadline, but the configure script discards the env set by NixOS before checking for -lreadline
    substituteInPlace configure --replace '-lreadline' '-lreadline -lncurses'

    substituteInPlace emc/usr_intf/pncconf/private_data.py --replace '/usr/share/themes' '${gtk3}/share/themes'
    substituteInPlace emc/usr_intf/pncconf/private_data.py --replace 'self.FIRMDIR = "/lib/firmware/hm2/"' 'self.FIRMDIR = os.environ.get("HM2_FIRMWARE_DIR", "${placeholder "out"}/firmware/hm2")'

    substituteInPlace hal/drivers/mesa-hostmot2/hm2_eth.c --replace '/sbin/iptables' '/run/current-system/sw/bin/iptables'
    substituteInPlace hal/drivers/mesa-hostmot2/hm2_eth.c --replace '/sbin/sysctl' '${sysctl}/bin/sysctl'
    substituteInPlace hal/drivers/mesa-hostmot2/hm2_rpspi.c --replace '/sbin/modprobe' '${kmod}/bin/modprobe'
    substituteInPlace hal/drivers/mesa-hostmot2/hm2_rpspi.c --replace '/sbin/rmmod' '${kmod}/bin/rmmod'
    substituteInPlace module_helper/module_helper.c --replace '/sbin/insmod' '${kmod}/bin/insmod'
    substituteInPlace module_helper/module_helper.c --replace '/sbin/rmmod' '${kmod}/bin/rmmod'
  '';

  configureFlags = [
    "--with-tclConfig=${tcl}/lib/tclConfig.sh"
    "--with-tkConfig=${tk}/lib/tkConfig.sh"
    "--with-boost-libdir=${boost_python}/lib"
    "--with-boost-python=boost_python3"
    "--with-locale-dir=$(out)/locale"
    "--exec-prefix=${placeholder "out"}"
  ];

  preInstall = ''
    # Stop the Makefile attempting to set ownship+perms, it fails on NixOS
    sed -i -e 's/chown.*//' -e 's/-o root//g' -e 's/-m [0-9]\+//g' Makefile
  '';

  installFlags = [ "SITEPY=${placeholder "out"}/${pythonPkg.sitePackages}" ];

  postInstall = ''
    mkdir -p "$out/firmware/hm2"
  '';

  # Binaries listed here are renamed to ${filename}-nosetuid, to be targetted by setuid wrappers
  setuidApps = [ "rtapi_app" "linuxcnc_module_helper" "pci_write" "pci_read" ];

  preFixup = ''
    for prog in $(find $out/bin -type f ! \( ${lib.concatMapStringsSep " -o " (f: "-name " + f + " ") setuidApps} \)); do
      wrapProgram "$prog" \
        --prefix PATH : ${lib.makeBinPath [tk glxinfo]} \
        --prefix TCLLIBPATH ' ' "$out/lib/tcltk/linuxcnc ${tk}/lib ${tcl}/lib ${tclx}/lib ${tkblt}/lib ${tkimg}/lib ${bwidget}/lib/bwidget${bwidget.version}" \
        --prefix PYTHONPATH : "${pythonPkg}/${pythonPkg.sitePackages}:$out/${pythonPkg.sitePackages}" \
        "''${gappsWrapperArgs[@]}" \
        "''${qtWrapperArgs[@]}"
    done
    for prog in $(find $out/bin -type f \( ${lib.concatMapStringsSep " -o " (f: "-name " + f + " ") setuidApps} \)); do
      mv "$prog" "$prog-nosetuid"
    done
  '';
}
