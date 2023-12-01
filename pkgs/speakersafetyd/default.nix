{ lib, fetchFromGitHub, rustPlatform, pkg-config, alsa-lib }:
rustPlatform.buildRustPackage rec {
  pname = "speakersafetyd";
  version = "0.1.4";

  src = fetchFromGitHub {
    owner = "AsahiLinux";
    repo = pname;
    rev = "38e5b9f4c450e216e5ec24d66b1e61016f68b6b7";
    hash = "sha256-D5zl6nrDecuX1fm/4AYc2RPhvmHuvhCRYkFpOv+XDDA=";
  };

  cargoHash = "sha256-hWMQGhcIM+SES2XWKvQvPYzoM1AEe2zvN3z2GXWihNs=";

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ alsa-lib ];

	preBuild = ''
		cargo update --offline
	'';

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
