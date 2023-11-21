{ stdenv, lib, fetchFromGitHub }:

stdenv.mkDerivation rec {
	pname = "asahi-audio";
	version = "0.5";

	src = fetchFromGitHub {
		owner = "AsahiLinux";
		repo = "asahi-audio";
		rev = "v${version}";
		sha256 = "sha256-vzzuYAw9w1khpnafIo2tdY9Rxo6fFGybNDJcJg+4QLE=";
	};

	preBuild = ''
		export PREFIX=$out

		readarray -t configs < <(\
			find . \
				-name '*.conf' -or \
				-name '*.json' -or \
				-name '*.lua'
		)

		substituteInPlace "''${configs[@]}" --replace \
			"/usr/share/asahi-audio" \
			"$out/share/asahi-audio"
	'';
}
