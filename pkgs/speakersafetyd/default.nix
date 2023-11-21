{ lib, fetchFromGitHub, rustPlatform, pkg-config, alsa-lib }:
rustPlatform.buildRustPackage rec {
  pname = "speakersafetyd";
  version = "0.1.4";

  src = fetchFromGitHub {
    owner = "AsahiLinux";
    repo = pname;
    rev = "247713720aac48df07447c55f7a6e06592995546";
    hash = "sha256-r0Tz2I7XyT9HCYeL7DQ4/G4ropc+2V6cfKXRggfRpNo=";
  };

  cargoHash = "sha256-gQzsA61C84OwkTDLzOezeY0ylt54I+OhXFLPdpSBdPY=";

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ alsa-lib ];

  installPhase = ''
    export VARDIR=$TMPDIR/var # don't care
		export BINDIR=$out/bin
		export UDEVDIR=$out/lib/udev/rules.d
		export UNITDIR=$out/share/systemd/system
		export SHAREDIR=$out/share

    make
    make install
  '';

  meta = with lib; {
    description = "Rust speaker safety daemon for Asahi Linux";
    homepage = "https://github.com/AsahiLinux/speakersafetyd";
    license = licenses.mit;
    maintainers = [ maintainers.RossComputerGuy ];
  };
}
