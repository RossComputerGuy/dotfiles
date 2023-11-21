{
	lib,
	lv2,
	pkg-config,
	rustPlatform,
	fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
	pname = "bankstown";
	version = "1.0.0";

	src = fetchFromGitHub {
		owner = "chadmed";
		repo = "bankstown";
		rev = "${version}";
		sha256 = "sha256-2Tm9ujOu5t8SLrfuUkqfbSiXbjpA0hBV5J5UA1wmlyA=";
	};

	cargoSha256 = "sha256-6kk9AEb9umb6MTT6sHCkviUdY7+FHPSnE7Z4wmmn5t0=";
	cargoPatches = [
		(builtins.fetchurl "https://patch-diff.githubusercontent.com/raw/chadmed/bankstown/pull/3.patch")
	];

	# preBuild = ''
	# 	cargo update --offline
	# '';

	installPhase = ''
		export LIBDIR=$out/lib
		mkdir -p $LIBDIR

		make
		make install
	'';

	nativeBuildInputs = [
		pkg-config
	];

	buildInputs = [
		lv2
	];
}
