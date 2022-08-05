{ lib
, stdenv
, fetchFromGitHub
, gtk-engine-murrine
, gtk_engines
, gitUpdater
, pkgs
}:

stdenv.mkDerivation rec {
  pname = "tokyonight-gtk-themes";
  version = "master";

  src = fetchFromGitHub {
    owner = "caldwellb";
    repo = pname;
    rev = version;
    sha256 = "sha256-eGSzMfgTracQ9Krb37XcCyADHJIIQy6ybHnppxhAh38=";
  };

  nativeBuildInputs = with pkgs; [
    gnome.gnome-shell
    sassc
  ];

  buildInputs = [
    gtk_engines
  ];

  postPatch = ''
    patchShebangs install.sh
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/themes
    name= HOME="$TMPDIR" ./install.sh --all --dest $out/share/themes
    rm $out/share/themes/*/{AUTHORS,LICENSE}
    runHook postInstall
  '';

  passthru.updateScript = gitUpdater {inherit pname version; };

  meta = with lib; {
    description = "Flat Material Design theme for GTK based desktop environments";
    homepage = "https://github.com/caldwellb/tokyonight-gtk-themes";
    license = licenses.gpl3Only;
    platforms = platforms.unix;
    maintainers = [ maintainers.romildo ];
  };
}
