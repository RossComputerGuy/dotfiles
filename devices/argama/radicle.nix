{
  config,
  lib,
  pkgs,
  ...
}:
let
  # The node identity. `rad auth` makes the pair, and this half is public, so it
  # belongs in the configuration where it can be read.
  #
  # Paste the one line from /var/lib/radicle/keys/radicle.pub here, with no
  # comment on the end. Radicle stays off until you do, because a seed node with
  # no identity cannot start. See the README.
  publicKey = "";

  # The agent writes the private half into the PrivateTmp of the sidecar. The
  # unit below copies it to /run, because the module gives it to radicle-node
  # with LoadCredential= and systemd resolves a credential before the unit joins
  # the agent's namespace. That is the same problem harmonia has, and the same
  # answer. See secrets.nix.
  keyDir = "/run/radicle-key";
  agent = config.detsys.vaultAgent.systemd.services.radicle-key;
in
{
  # Radicle sits next to Forgejo, it does not replace it. Forgejo keeps the web
  # interface behind the single sign on, the mirror that pulls from GitHub, and
  # the plain HTTPS clone that every tool already understands. Radicle holds the
  # copy that does not die with this machine: every node that seeds a repository
  # holds a whole one.
  #
  # Only argama seeds today. A second machine joins by running `rad auth` of its
  # own, then `rad seed <rid>`. It finds argama at the external address below,
  # over the tailnet. Nothing here has to change for that.
  services.radicle = {
    enable = publicKey != "";
    inherit publicKey;

    privateKey = "${keyDir}/radicle";

    node = {
      # Bind everywhere, then let the firewall decide. Only the tailnet reaches
      # this port, see below.
      listenAddress = "[::]";
      listenPort = 8776;
      # The module would open the port on every interface. The rule below opens
      # it on the tailnet alone.
      openFirewall = false;
    };

    httpd = {
      enable = true;
      listenAddress = "127.0.0.1";
      # 8080 is the qBittorrent web interface, see media.nix.
      listenPort = 8081;
      # The module can write an nginx virtual host. Caddy serves this zone, so
      # the name comes from service-ports.nix instead. Leave this null.
      nginx = null;
    };

    settings = {
      node.alias = "argama";
      # What a peer dials to reach this node. The name resolves on the tailnet,
      # the same as the OpenBao address in secrets.nix.
      node.externalAddresses = [ "argama:8776" ];
    };

    # checkConfig stays on. It runs `rad config` against the generated
    # config.json at build time, so a wrong key fails the build and not the boot.
  };

  # The module puts only `rad-system` on the PATH, and only when the service is
  # on. That wrapper runs `rad` inside the namespaces of a *running* node, so it
  # cannot make the identity that the node needs before it can run. Give the
  # plain command as well, so the first `rad auth` is possible.
  environment.systemPackages = [ config.services.radicle.package ];

  # The gossip port, on the tailnet only. A second machine that seeds these
  # repositories reaches argama here. To seed to the public internet later, move
  # this to networking.firewall.allowedTCPPorts and give the node an external
  # address that resolves outside the tailnet.
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 8776 ];

  # Put the private key in OpenBao with:
  #   bao kv put secret/argama/radicle private_key=@/var/lib/radicle/keys/radicle
  #
  # The key must carry no passphrase. The module asks systemd for the passphrase
  # as a credential, and the agent cannot supply a credential for the same reason
  # it cannot supply the key itself.
  detsys.vaultAgent.systemd.services.radicle-key = {
    enable = true;
    secretFiles.files."radicle" = {
      changeAction = "restart";
      template = ''
        {{ with secret "secret/data/argama/radicle" }}{{ .Data.data.private_key }}{{ end }}
      '';
    };
  };

  systemd.services = lib.mkIf config.services.radicle.enable {
    radicle-key = {
      description = "Publish the radicle node key where LoadCredential can read it";
      requiredBy = [ "radicle-node.service" ];
      before = [ "radicle-node.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        RuntimeDirectory = "radicle-key";
        RuntimeDirectoryMode = "0700";
        # Keep the directory across a restart of this unit, so the node never
        # finds the key missing while the key is written again.
        RuntimeDirectoryPreserve = "yes";
        ExecStart = pkgs.writeShellScript "radicle-key-publish" ''
          ${lib.getExe' pkgs.coreutils "install"} -m 0400 \
            ${agent.secretFiles.files."radicle".path} \
            ${keyDir}/radicle
        '';
      };
    };

    # A new key means the node must load it again.
    radicle-node = {
      after = [ "radicle-key.service" ];
      bindsTo = [ "radicle-key.service" ];
    };
  };

  # Hydra reads a jobset from a flake URL, and radicle-httpd serves a repository
  # over plain git as well as the browsing API. So a jobset input of
  # git+https://radicle.argama.nix/<rid>.git builds straight from the seed.
  #
  # No continuous integration broker here. Radicle has one, but Hydra already
  # does the building on this machine and two build systems would only disagree.
}
