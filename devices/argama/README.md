# Argama

Ampere 64-core homelab server on an ASRockRack ALTRAD8UD-1L2T, the same board as
zeta3a. Mobile suits are endpoints, ships are infrastructure.

| File             | Holds                                          |
| ---------------- | ---------------------------------------------- |
| `default.nix`    | Boot, storage, network, Nix builder, Hydra      |
| `secrets.nix`    | OpenBao and every agent that reads from it      |
| `web.nix`        | Caddy, the named entry points and the local CA  |
| `media.nix`      | Jellyfin, the arr stack, qBittorrent, Mullvad   |
| `backup.nix`     | The restic server that the fleet pushes to      |
| `monitoring.nix` | Prometheus, the exporters and Grafana           |
| `dns.nix`        | blocky and unbound, and the `.nix` zone         |
| `git.nix`        | Forgejo                                         |
| `documents.nix`  | Paperless                                       |

The client half lives in `modules/backup.nix`, which every Linux machine gets.
A machine turns it on with `ross.backup.enable`.

## The .nix zone

argama answers for its own internal zone. blocky has no per-client answers, so
split horizon runs two instances: the NixOS module one on the LAN address, and
`blocky-tailnet` on the tailnet address. Each answers the zone with its own
side's address, so a machine at home takes the LAN path and a machine away from
home takes the tailnet.

**Set `lanAddress` and `tailnetAddress` at the top of `dns.nix` before the first
boot.** They are placeholders.

| Name                | Reaches            |
| ------------------- | ------------------ |
| `argama.nix`        | argama             |
| `backup.argama.nix` | The restic server  |
| `vault.argama.nix`  | OpenBao            |

Caddy terminates both names on 443 with `tls internal`, so it signs them with
its own authority. No public authority can sign for a `.nix` name.

## Names

Every service answers at a name, and Caddy is the only way to any of them. No
service has a port of its own open. `service-ports.nix` holds the one list that
the zone, the virtual hosts and the names on the certificate all come from, so
they cannot drift apart.

| Name                    | Reaches     | Login    |
| ----------------------- | ----------- | -------- |
| `auth.argama.nix`       | Authelia    | itself   |
| `seerr.argama.nix`      | Seerr       | Authelia |
| `sonarr.argama.nix`     | Sonarr      | Authelia |
| `radarr.argama.nix`     | Radarr      | Authelia |
| `prowlarr.argama.nix`   | Prowlarr    | Authelia |
| `qbit.argama.nix`       | qBittorrent | Authelia |
| `hydra.argama.nix`      | Hydra       | Authelia |
| `git.argama.nix`        | Forgejo     | Authelia |
| `radicle.argama.nix`    | Radicle     | none     |
| `grafana.argama.nix`    | Grafana     | Authelia |
| `prometheus.argama.nix` | Prometheus  | Authelia |
| `paperless.argama.nix`  | Paperless   | Authelia |
| `dns.argama.nix`        | blocky      | Authelia |
| `jellyfin.argama.nix`   | Jellyfin    | its own  |
| `backup.argama.nix`     | restic      | its own  |
| `vault.argama.nix`      | OpenBao     | its own  |
| `cache.argama.nix`      | harmonia    | none     |

## Single sign on

Authelia sits in front of every name marked above. Caddy asks it about each
request first and passes the request on only when it says yes, so one login
covers all of them. The second factor is the YubiKey, which is already in hand
for the OpenBao unseal.

Five names do their own checking, each for a reason:

- **Jellyfin.** A forward check works by sending a browser to a login page. A
  television, a phone application or a Chromecast cannot follow that, so
  guarding Jellyfin here would break every client that is not a browser. Its own
  accounts stay the boundary.
- **restic.** It speaks HTTP basic authentication and follows no redirect.
- **OpenBao.** It has its own tokens, and it holds Authelia's secrets, so it must
  answer before Authelia can start.
- **harmonia.** The Nix daemon follows no login redirect. The cache needs no
  login either, since every store path carries a signature.
- **Radicle.** `radicle-httpd` is read only. It serves the browsing API and a
  git clone over HTTP, and git follows no redirect either. A write never touches
  this name. It goes to the node on 8776, which checks a signature.

Authelia's own secrets come from OpenBao. It reads them with `LoadCredential=`,
so the `authelia-keys` unit copies them to `/run` first, the same way
`harmonia-key` does. The user list, with its argon2 password hash, comes from
OpenBao too.

The arr applications talk to qBittorrent and to Prowlarr on `127.0.0.1`, never
through Caddy, so the guard does not break them.

A later refinement is native OpenID Connect for Grafana, Forgejo and Paperless.
They each support it, and it would drop the second login inside those three
after Authelia has already let a person through.

`cache.argama.nix` answers on plain HTTP, and every other name on TLS. The
binary cache cannot use TLS, because the Nix daemon needs a certificate
authority in its trust store before it starts and OpenBao gives a machine
argama's authority long after that. It does not need TLS: every store path
carries a signature which a client checks against `trusted-public-keys`, so a
changed byte on the wire fails that check.

### Open ports

| Port  | Open on          | Why                                          |
| ----- | ---------------- | -------------------------------------------- |
| 22    | every interface  | ssh                                          |
| 53    | every interface  | argama answers DNS for the whole house       |
| 80    | every interface  | Caddy, for `cache.argama.nix`                |
| 443   | every interface  | Caddy, for every other name                  |
| 8200  | the tailnet only | OpenBao, the one exception below             |
| 8776  | the tailnet only | The Radicle node, see below                  |

OpenBao keeps a port of its own because trust has to start somewhere. A client's
agent reads argama's certificate authority *from* OpenBao, so it cannot check a
certificate signed by that authority until after it has read it. Tailscale
encrypts that link.

The Radicle node speaks its own protocol, not HTTP, so Caddy cannot carry it. A
peer that seeds these repositories dials 8776 directly.

## Radicle

Radicle sits next to Forgejo. It does not replace it.

| | Forgejo | Radicle |
| --- | --- | --- |
| Web interface | yes, behind Authelia | `rad` on the command line |
| Login | Authelia | a keypair, no accounts |
| Mirror from GitHub | yes, on a timer | no |
| Large file storage | yes | no |
| Clone over HTTPS | yes | read only |
| Push | over HTTPS | over the node protocol |
| Survives argama | no | yes |

That last row is the whole reason it is here. A Forgejo repository lives on this
one machine. A Radicle repository lives on every node that seeds it, so argama
can burn and the repository still exists.

Only argama seeds today. A second machine joins later with `rad auth` of its own
and then `rad seed <rid>`. It finds argama at `argama:8776` over the tailnet.
Nothing in this configuration has to change for that.

To seed to the public internet instead, move 8776 from the tailnet rule to
`networking.firewall.allowedTCPPorts` and give `node.externalAddresses` a name
that resolves outside the tailnet.

### Starting the node

Radicle stays off until the node has an identity. `radicle.nix` holds an empty
`publicKey`, and `services.radicle.enable` reads it, so the configuration builds
today and the node starts on the day you fill it in.

Make the identity on argama. `rad` writes to `$RAD_HOME`, which is
`~/.radicle` by default, so name a scratch directory instead. The service keeps
its own `/var/lib/radicle` and reads the key from OpenBao, so nothing here has
to land in that directory:

```
export RAD_HOME=$(mktemp -d)
rad auth --alias argama
```

Press Enter at the passphrase prompt to leave it empty. The key must carry no
passphrase, because `services.radicle.privateKeyPassphrase` names a systemd
credential and not a file. systemd reads that name with `ImportCredential=`,
which looks only in the credential store, so a file the agent writes can never
satisfy it. The file permissions and the tailnet are the boundary instead.

If the node says `keystore is encrypted; a passphrase is required`, the key went
in with a passphrase. Take the passphrase off and put the key back. This keeps
the same identity, so `publicKey` does not change:

```
umask 077
export RAD_HOME=$(mktemp -d)
bao kv get -field=private_key secret/argama/radicle > $RAD_HOME/radicle
ssh-keygen -p -f $RAD_HOME/radicle
ssh-keygen -y -f $RAD_HOME/radicle
bao kv put secret/argama/radicle private_key=@$RAD_HOME/radicle
shred -u $RAD_HOME/radicle && rmdir $RAD_HOME
```

`ssh-keygen -p` asks for the old passphrase, then for the new one two times.
Press Enter both times to leave it empty. The line that `ssh-keygen -y` prints
must equal `publicKey` in `radicle.nix`, apart from the alias on the end. Then
make the agent read the new value and start the node again:

```
sudo systemctl restart detsys-vaultAgent-radicle-key radicle-key
```

Put the private half in OpenBao, and copy the public half into the
configuration:

```
bao kv put secret/argama/radicle \
  private_key=@$RAD_HOME/keys/radicle

cat $RAD_HOME/keys/radicle.pub
```

Paste that one line into `publicKey` in `radicle.nix`, with no comment on the
end, then rebuild. `checkConfig` runs `rad config` against the generated
`config.json` while it builds, so a wrong setting fails the build and not the
boot. Then remove the scratch directory, because it still holds a copy of the
private key:

```
shred -u $RAD_HOME/keys/radicle
rm -rf $RAD_HOME
```

### Day to day

`rad-system` runs `rad` inside the node's own namespaces, as the radicle user.
Use it for anything that touches the seed:

```
rad-system seed <rid>
rad-system node status
```

Hydra reads a jobset from a flake URL, and `radicle-httpd` serves a repository
over plain git, so a jobset input of
`git+https://radicle.argama.nix/<rid>.git` builds straight from the seed.

There is no Radicle continuous integration broker here. Radicle has one, but
Hydra already builds on this machine and two build systems would only disagree.

## Secrets

Only two things stay on disk. Everything else comes from OpenBao.

| Path                             | Mode | Holds                 |
| -------------------------------- | ---- | --------------------- |
| `/var/lib/vault-agent/role-id`   | 0600 | OpenBao AppRole ID    |
| `/var/lib/vault-agent/secret-id` | 0600 | OpenBao AppRole secret |

These two are the root of trust for the agent, so they cannot come from OpenBao
itself.

| OpenBao path             | Field            | Goes to                  |
| ------------------------ | ---------------- | ------------------------ |
| `secret/argama/mullvad`  | `config`         | The WireGuard tunnel     |
| `secret/argama/harmonia` | `signing_key`    | The binary cache key     |
| `secret/argama/grafana`  | `secret_key`     | Grafana's database key   |
| `secret/argama/paperless` | `admin_password` | The Paperless superuser |
| `secret/argama/radicle`  | `private_key`    | The Radicle node identity |

### How the agent delivers a secret

The agent writes to two places, and which one a service can use depends on how
that service reads its secret.

- **`/tmp/detsys-vault/`** is inside the unit's `PrivateTmp`. A service that
  opens the file itself can read it. Grafana and the Mullvad tunnel use this.
- **`/run/keys/environment/`** is a normal path, because `PrivateTmp` covers
  `/tmp` and `/var/tmp` only. A service that takes an environment variable uses
  this. Paperless does.

A service that reads its secret with `LoadCredential=` can use neither
directly, because systemd resolves a credential before the unit joins the
agent's namespace. harmonia is one of these. The `harmonia-key` unit in
`secrets.nix` solves it: that unit does join the namespace, so it copies the key
to `/run/harmonia-key/`, which `LoadCredential=` can then read.

## Storage

| Pool    | Disks                                | Holds                          |
| ------- | ------------------------------------ | ------------------------------ |
| `zpool` | one 931GB NVMe                       | `root`, `nix`, `var`, `home`   |
| `tank`  | twelve 7TB disks, four mirrors of 3  | `media`, `backups`             |

`tank` gives 4 disks of space out of 12, near 28TB, and survives 2 failures in
each group of 3. It grows a group at a time, so it starts at one group of three
and 7TB. See "Growing tank" below.

| Groups | Disks | Space |
| ------ | ----- | ----- |
| 1      | 3     | 7TB   |
| 2      | 6     | 14TB  |
| 3      | 9     | 21TB  |
| 4      | 12    | 28TB  |

## Install steps

The pools and the EFI partition are not declarative. Make them by hand from the
installer before the first `nixos-install`. Put the NVMe in `DISK` first, and
read every command before you run it, because the first one erases that disk.

`tank` does not need all twelve disks on the first day. Its shape is four
separate groups striped together, so each group is added on its own and a pool
of one group grows into a pool of four. Make it with the disks that `lsblk`
shows, and add each later group with `zpool add`.

```
DISK=/dev/nvme0n1
```

The console needs no setting. argama is the same board as zeta3a, an ASRockRack
ALTRAD8UD-1L2T, and its firmware gives the kernel an SPCR table that names the
console. `default.nix` passes `earlycon` only, which reads that same table.

### 0. The YubiKey

The YubiKey is the credential from the first command, not something added later.
Slot 2 already answers a challenge with an HMAC, and both keys carry the same
secret, so nothing needs programming again. argama only needs its own challenge
strings, which are not secrets:

```
ykchalresp -2 "argama-zpool-2026"
ykchalresp -2 "argama-tank-2026"
```

Write those two strings down. They are not secret, but the answer cannot be
worked out without them, and a key with no challenge opens nothing.

Confirm the spare really carries the same secret before you trust it as a spare.
The same challenge must give the same answer on both keys:

```
ykchalresp -2 "test"      # first key, then swap to the second and repeat
```

If the two answers differ, the second key never took the secret, and fixing that
now is far easier than finding out later.

### 1. Partition

```
sgdisk --zap-all "$DISK"
sgdisk -n1:0:+1G -t1:ef00 -c1:boot  "$DISK"
sgdisk -n2:0:0   -t2:bf00 -c2:zpool "$DISK"
partprobe "$DISK"

# default.nix mounts /boot by this label, so the name matters.
mkfs.vfat -n boot /dev/disk/by-partlabel/boot
```

### 2. Make the pools

argama has two pools. `zpool` is the NVMe and holds the system. `tank` is the
spinning disks and holds the bulk data, because a 931GB NVMe holds neither a
media library nor the backups of a fleet.

Both are encrypted at the pool, so every dataset below them is encrypted too.
The YubiKey answer is the passphrase from the start. Write it to a file that the
pool reads once, because `zpool create` asks for a new passphrase twice and a
pipe answers only the first ask:

```
ykchalresp -2 "argama-zpool-2026" > /tmp/zpool.pass

zpool create -f \
  -o ashift=12 \
  -o autotrim=on \
  -O acltype=posixacl \
  -O xattr=sa \
  -O relatime=on \
  -O compression=zstd \
  -O encryption=on \
  -O keyformat=passphrase \
  -O keylocation=file:///tmp/zpool.pass \
  -O mountpoint=none \
  zpool /dev/disk/by-partlabel/zpool

# The file was for the making of the pool only. From here the pool asks.
zfs set keylocation=prompt zpool
```

`/tmp` in the installer is memory and goes at the next boot, but remove the file
anyway once both pools exist.

`tank` is 12 drives as four mirrors of three, striped. Each `mirror` word starts
a new top level group, and ZFS stripes across the groups. It gives 4 drives of
space out of 12, and it survives 2 failures in each group of 3.

**Use `/dev/disk/by-id/` names, never `sdb` and `sdc`.** Those letters are handed
out in the order the kernel finds the drives, so they move when a cable, a slot
or an HBA changes, and with 12 drives they will move. Read the stable names
first, and prefer a `wwn-` or a model and serial name over a `scsi-` one:

```
ls -l /dev/disk/by-id/ | grep -vE 'part[0-9]|/dev/sda|nvme'
```

```
ykchalresp -2 "argama-tank-2026" > /tmp/tank.pass

zpool create -f \
  -o ashift=12 \
  -O acltype=posixacl \
  -O xattr=sa \
  -O atime=off \
  -O compression=zstd \
  -O encryption=on \
  -O keyformat=passphrase \
  -O keylocation=file:///tmp/tank.pass \
  -O mountpoint=none \
  tank \
  mirror /dev/disk/by-id/<d1>  /dev/disk/by-id/<d2>  /dev/disk/by-id/<d3>  \
  mirror /dev/disk/by-id/<d4>  /dev/disk/by-id/<d5>  /dev/disk/by-id/<d6>  \
  mirror /dev/disk/by-id/<d7>  /dev/disk/by-id/<d8>  /dev/disk/by-id/<d9>  \
  mirror /dev/disk/by-id/<d10> /dev/disk/by-id/<d11> /dev/disk/by-id/<d12>

zfs set keylocation=prompt tank
shred -u /tmp/zpool.pass /tmp/tank.pass
```

Check the shape before you trust it. Every `mirror-N` should hold three drives:

```
zpool status tank
```

#### The first group

The disks in the machine. A `wwn-` and a `scsi-` name point at each one, and
both are stable, but `wwn-` comes from the drive itself, so it holds even when
the `sd` letters move. They do move: pull one disk and the ones after it shift
up a letter.

| wwn                        | State                                        |
| -------------------------- | -------------------------------------------- |
| `wwn-0x5002538ae86f8e20`   | in the pool                                  |
| `wwn-0x5002538ae86338d0`   | in the pool                                  |
| `wwn-0x5002538ae86d0ab0`   | in the pool                                  |

Clear anything a failed attempt left behind, or ZFS finds an old label and
refuses:

```
for d in /dev/disk/by-id/wwn-0x5002538ae86f8e20 \
         /dev/disk/by-id/wwn-0x5002538ae86338d0; do
  wipefs -a "$d"; sgdisk --zap-all "$d"
done
```

Then make the group. Two disks mirror as happily as three, survive one failure
just the same, and hold the same 7TB, because a mirror's size is one disk:

```
ykchalresp -2 "argama-tank-2026" > /tmp/tank.pass

zpool create -f \
  -o ashift=12 \
  -o autotrim=on \
  -O acltype=posixacl \
  -O xattr=sa \
  -O atime=off \
  -O compression=zstd \
  -O encryption=on \
  -O keyformat=passphrase \
  -O keylocation=file:///tmp/tank.pass \
  -O mountpoint=none \
  tank \
  mirror \
    /dev/disk/by-id/wwn-0x5002538ae86f8e20 \
    /dev/disk/by-id/wwn-0x5002538ae86338d0 \
    /dev/disk/by-id/wwn-0x5002538ae86d0ab0

zfs set keylocation=prompt tank
```

Read the shape back. One `mirror-0`, and the names in it must be the `wwn-`
ones and not `sdb` and friends:

```
zpool status tank
```

Widening it to three later does not need a new group. `attach` adds a disk to
the mirror that is already there, and ZFS copies onto it:

```
zpool attach tank wwn-0x5002538ae86f8e20 \
  /dev/disk/by-id/wwn-0x5002538ae86d0ab0
zpool status tank      # watch the resilver finish before trusting it
```

#### Growing tank

Make `tank` with the groups you have. With three disks, that is the first
`mirror` line and nothing after it, which gives 7TB and survives 2 failures.
Add each later group of three the same way:

```
zpool add tank \
  mirror /dev/disk/by-id/<d4> /dev/disk/by-id/<d5> /dev/disk/by-id/<d6>
```

Each group must hold three disks, the same as the first. `zpool add` accepts a
group of a different width and then refuses to explain later why one disk
failing lost the pool, so read the shape back with `zpool status` every time.

ZFS does not move old data onto a new group. What is already written stays where
it is, and only new writes use the new space, so the pool leans on its first
group until enough new data arrives. Nothing is at risk, and the reads are
slower than a pool that was made with all twelve at once. Sending the datasets
away and back is the only way to even them out.

### 3. Make the datasets

`mountpoint=legacy` gives the mounting to NixOS, which is what the `fileSystems`
entries in `default.nix` expect. A dataset with any other mountpoint would be
mounted twice.

```
zfs create -o mountpoint=legacy -o canmount=on zpool/root
zfs create -o mountpoint=legacy -o canmount=on zpool/var
zfs create -o mountpoint=legacy -o canmount=on zpool/home

# The store holds many copies of nearly the same file, so it is the one place
# where dedup pays for the memory it costs.
zfs create -o mountpoint=legacy -o canmount=on -o dedup=on \
  -o compression=zstd-9 zpool/nix

# Video and music are compressed already, and so is a restic repository.
# Compression here would only spend CPU. A large record suits both, because
# each holds big files that are read from end to end.
zfs create -o mountpoint=legacy -o canmount=on \
  -o compression=off -o recordsize=1M tank/media
zfs create -o mountpoint=legacy -o canmount=on \
  -o compression=off -o recordsize=1M \
  -o reservation=2T tank/backups
```

The reservation keeps 2TB for the backups whatever else happens. Sonarr and
Radarr download on their own and a library grows to whatever room it finds, so
without it the media would take the last free byte and the fleet would stop
backing up. Raise it as the pool grows. `zfs set reservation=4T tank/backups`
changes it at any time.

### 4. Mount and install

```
mount -t zfs zpool/root /mnt
mkdir -p /mnt/{boot,nix,var,home}
mount -t zfs zpool/nix  /mnt/nix
mount -t zfs zpool/var  /mnt/var
mount -t zfs zpool/home /mnt/home
mount /dev/disk/by-label/boot /mnt/boot

mkdir -p /mnt/var/lib/{media,restic}
mount -t zfs tank/media   /mnt/var/lib/media
mount -t zfs tank/backups /mnt/var/lib/restic

nixos-install --flake .#argama
```

`networking.hostId` is `8564d4ac` in `default.nix`. ZFS refuses to import a pool
whose host ID does not match, so leave it as it is.

**Do not reboot yet.** Step 5 comes first.

### 5. Give the pool keys to the TPM, before the first boot

Do this from the installer, while the pools are still imported and their keys
are still loaded. It is not optional and it does not wait until later.

`default.nix` sets `boot.zfs.requestEncryptionCredentials` to an empty list, so
stage 1 emits no `zfs load-key` and never asks for a passphrase. The TPM is
meant to hand the key over instead. A machine that reboots before the seal
exists has no way at all to open its root pool: it drops to an emergency shell
that no passphrase can reach, and the installer USB becomes the only way back.

**No `-P` on this first seal.** lanzaboote enrolls the secure boot keys on the
first boot, which moves PCR 7, and a key bound to PCR 7 now would refuse to open
on the second boot. Press Enter at each passphrase prompt to leave it empty, so
the seal opens whatever the firmware state turns out to be:

```
nix shell nixpkgs#tzpfms

zfs-tpm2-change-key -b /mnt/root/zpool.key zpool
zfs-tpm2-change-key -b /mnt/root/tank.key  tank

zfs-tpm-list -a        # both pools, TPM2, COHERENT yes
```

`-b` writes to `/mnt/root` and not `/root`, because the installer's own `/root`
is memory and goes at the reboot.

Between now and step 6 the pools open on this TPM whatever the firmware does, so
anyone holding the machine can read them. That window is while you stand at the
machine, and step 6 closes it.

Now reboot.

### 6. Bind the seal to secure boot, and keep a way back

Do this after the first boot, once `sbctl status` shows the keys enrolled. It
adds the PCR binding the step above had to leave off, and a YubiKey fallback.

Two flags matter here.

`-P sha256:7` binds the key to PCR 7, the state of secure boot, so the TPM
releases it only to a machine that still boots the same way.

`-A` adds a passphrase to the sealed object. The TPM ORs it with the PCR
policy, so the key opens **either** with no passphrase and the right PCR 7,
**or** with the passphrase and any PCR 7. That is the fallback: an ordinary boot
needs nobody, and a boot after the secure boot keys change still opens with the
passphrase. Give the YubiKey answer as that passphrase, so the fallback is the
key in a pocket and not a string to remember.

`-b` writes a copy of the new key to a file. **Take it.** It is the only way in
if the TPM itself is gone, because a dead board and a cleared TPM take both of
the paths above with them.

`TZPFMS_PASSPHRASE_HELPER` gives the YubiKey answer to `-A` instead of the
keyboard. It runs under `sh -c` and its output becomes the passphrase. This ran
on zeta3a and is the form to copy:

The file names differ from step 5 on purpose. `-b` refuses a file that is already
there, and step 5 left `/root/zpool.key` and `/root/tank.key` behind:

```
sudo env TZPFMS_PASSPHRASE_HELPER='ykchalresp -2 argama-zpool-2026' \
  zfs-tpm2-change-key -b /root/zpool-sealed.key -P sha256:7 -A zpool

sudo env TZPFMS_PASSPHRASE_HELPER='ykchalresp -2 argama-tank-2026' \
  zfs-tpm2-change-key -b /root/tank-sealed.key -P sha256:7 -A tank
```

This makes a **new** wrapping key for each pool, so the two files step 5 wrote
open nothing from here on. Destroy them once the new ones are proved below:

```
sudo shred -u /root/zpool.key /root/tank.key
```

Each prints `Key for <pool> changed` and asks nothing, because the helper
answers. **Silence is not proof that `-A` took**, since a command without `-A`
is just as quiet. The helper in the line above is the proof, so keep it in the
shell history or note it down.

The helper answers every prompt it is given, so use it only when the TPM owner
hierarchy has no passphrase of its own. Otherwise answer by hand.

#### Put the backups where only the YubiKey opens them

The card holds the private half only. To encrypt, this machine needs the public
key, and the card says where to get it:

```
gpg --edit-card      # then: fetch, then: quit
# or, the same thing without the menu:
curl -sL https://github.com/RossComputerGuy.gpg | gpg --import
gpg --list-keys      # 9F167124D5EC917E is the encryption subkey
```

`sudo gpg` reads root's keyring, which is empty, so read the file as root and
encrypt as yourself. A freshly imported key carries no trust and gpg stops
rather than encrypt to one, so say `--trust-model always` or set the trust once
with `gpg --edit-key`, then `trust`, then `5`:

```
sudo cat /root/zpool-sealed.key | gpg --encrypt --recipient 9F167124D5EC917E \
  --trust-model always --output ~/zpool.key.gpg
sudo cat /root/tank-sealed.key  | gpg --encrypt --recipient 9F167124D5EC917E \
  --trust-model always --output ~/tank.key.gpg
```

**Prove both open before you destroy anything.** Each must give back 32 bytes,
which is the size of a raw wrapping key. Anything else means the file is wrong
and the plain copy is still the only one there is:

```
gpg --decrypt ~/zpool.key.gpg | wc -c     # must print 32
gpg --decrypt ~/tank.key.gpg  | wc -c     # must print 32
```

Only then:

```
chmod 600 ~/zpool.key.gpg ~/tank.key.gpg
sudo shred -u /root/zpool-sealed.key /root/tank-sealed.key
```

Now move both off argama. A copy that stays here protects against nothing,
because it burns with the machine, and these two files are what open the media
and every backup the fleet has sent. Do not put them on zeta3a either, since
the same YubiKey opens that machine's escrow as well.

### Three ways into a pool

| Way                    | Needs                        | When                          |
| ---------------------- | ---------------------------- | ----------------------------- |
| PCR 7, no passphrase   | the TPM, secure boot as it is | every ordinary boot           |
| the `-A` passphrase    | the TPM and the YubiKey       | after secure boot keys change |
| the `-b` backup file   | the YubiKey only              | the TPM or the board is gone  |

The second one does not prompt on its own during a boot. The unit that loads
these keys is a `oneshot` with no standard input, so a prompt there reads end of
file and the boot stops. Use it from the rescue shell, where a terminal is
attached:

```
zfs-tpm2-load-key zpool          # then give the YubiKey answer
```

The third one, from any rescue system:

```
gpg --decrypt zpool.key.gpg | zfs load-key zpool
```

#### Before you touch the secure boot firmware

Enrolling or clearing secure boot keys changes PCR 7, so the first way in stops
working. The second one still opens the pool, so this costs a trip to the rescue
shell with the YubiKey and not the pool. Boot, let the ordinary open fail, then:

```
zfs-tpm2-load-key zpool          # give the answer to argama-zpool-2026
zfs-tpm2-load-key tank           # and to argama-tank-2026
```

Once the machine is up on the new firmware, seal against the new PCR 7:

```
sudo env TZPFMS_PASSPHRASE_HELPER='ykchalresp -2 argama-zpool-2026' \
  zfs-tpm2-change-key -b /root/zpool.key -P sha256:7 -A zpool
```

That makes a **new** wrapping key, so the backup file from before dies the
moment it runs. Encrypt the new one, check that it opens to 32 bytes, and only
then destroy the old.

#### If a YubiKey is ever lost or replaced

The passphrase is an HMAC of the challenge under a secret in slot 2. A new key
needs that same secret, or the answers will not match and the second way in is
gone. Slot 2 was programmed this way, without `-ochal-btn-trig`, so the key
answers with no touch:

```
ykpersonalize -2 -ochal-resp -ochal-hmac -ohmac-lt64 -oserial-api-visible
```

The secret is the part to keep. Losing every key that carries it costs the
second way in but not the pool, because the backup file still opens it.

`boot.zfs.requestEncryptionCredentials` is forced empty in `default.nix`, so
stage 1 never asks for a passphrase. If the TPM cannot release the key, the
machine stops at that point and needs a console.

## After the first boot

1. Initialize OpenBao with the unseal shares encrypted to the YubiKey, so no
   plain share ever reaches this disk:

   You give OpenBao no key. It makes the unseal key and the root token itself.
   What you give it is the **public** half of the YubiKey's OpenPGP key, and it
   encrypts both results to that key before it prints them.

   argama's root keyring starts empty, so fetch the public half first. The card
   holds the private half only:

   ```
   curl -sL https://github.com/RossComputerGuy.gpg | gpg --import
   gpg --list-keys      # 9F167124D5EC917E is the encryption subkey
   ```

   One share and a threshold of one, because every share would go to the same
   key. Splitting a secret among one holder adds work and no safety:

   ```
   export BAO_ADDR=http://127.0.0.1:8200
   gpg --export 001047CA0BF783D10AEB5EF20A5B20F0FB92F1B0 | base64 > /tmp/yk.pub
   bao operator init -key-shares=1 -key-threshold=1 \
     -pgp-keys=/tmp/yk.pub -root-token-pgp-key=/tmp/yk.pub
   ```

   **Decode before you save.** `init` prints the share and the token as base64,
   and inside that base64 is a binary PGP message. gpg reads the message but not
   the base64 around it, so a file with the printed text in it fails to decrypt
   and `argama-unseal` stops with a gpg error. The `.asc` name is only the
   pattern the script globs for:

   ```
   echo '<Unseal Key 1>' | base64 -d > /var/lib/openbao/unseal-shares/1.asc
   echo '<Initial Root Token>' | base64 -d > /root/root-token.gpg
   chmod 600 /root/root-token.gpg
   ```

   Prove both open before you close the terminal that printed them. That output
   is the only other copy:

   ```
   gpg --decrypt /var/lib/openbao/unseal-shares/1.asc | head -c 20; echo
   gpg --decrypt /root/root-token.gpg
   ```

   Then unseal with the YubiKey in the machine:

   ```
   argama-unseal
   ```

   Until the unseal, Caddy, the Mullvad tunnel, qBittorrent, harmonia, Grafana
   and Paperless stay down. Their agents retry every 15 seconds and never give
   up, so all of them start by themselves after the unseal.

2. Enable the KV store and add the secrets from the table above:

   ```
   bao secrets enable -version=2 -path=secret kv
   bao kv put secret/argama/mullvad config=@wg0.conf
   bao kv put secret/argama/grafana secret_key=$(head -c 32 /dev/urandom | base64)
   bao kv put secret/argama/paperless admin_password=<password>
   ```

3. Make the cache signing key, put it in OpenBao, then remove the local copy:

   ```
   nix-store --generate-binary-cache-key argama-1 ./harmonia.secret ./harmonia.pub
   bao kv put secret/argama/harmonia signing_key=@harmonia.secret
   ```

   Add the contents of `harmonia.pub` to `nixConfig.trusted-public-keys` in
   `flake.nix`, and add `http://cache.argama.nix` to `substituters`.

4. Make an AppRole for argama's own agents, then write the role ID and the
   secret ID to the two paths in the table above. Nothing on this machine can
   read a secret until these two files exist, so every agent sits in a retry
   loop and each service it feeds reports "Dependency failed".

   The policy covers what argama's own templates ask for. `pki/issue/argama` is
   a write, not a read, because Caddy asks the PKI to make it a certificate:

   ```
   bao auth enable approle

   bao policy write argama - <<'EOF'
   path "secret/data/argama/*" {
     capabilities = ["read"]
   }
   path "pki/issue/argama" {
     capabilities = ["create", "update"]
   }
   EOF

   bao write auth/approle/role/argama \
     token_policies=argama \
     token_ttl=1h token_max_ttl=24h \
     secret_id_num_uses=0 secret_id_ttl=0
   ```

   The secret ID must not expire or burn after one use. `secrets.nix` sets
   `remove_secret_id_file_after_reading = false`, because the agent reads the
   file again after every restart. A secret ID with a life on it works until
   the first reboot and then stops the whole machine.

   ```
   install -d -m 0700 /var/lib/vault-agent

   bao read -field=role_id auth/approle/role/argama/role-id \
     > /var/lib/vault-agent/role-id
   bao write -f -field=secret_id auth/approle/role/argama/secret-id \
     > /var/lib/vault-agent/secret-id

   chmod 0600 /var/lib/vault-agent/role-id /var/lib/vault-agent/secret-id
   ```

   The agents retry every 15 seconds, so they find these by themselves. Watch
   one pick it up:

   ```
   journalctl -fu detsys-vaultAgent-caddy
   ```

5. Enroll the secure boot keys. `lanzaboote` makes and enrolls them, but the
   firmware must be in secure boot setup mode first. These keys stay on disk,
   and the note below says why the YubiKey does not hold them.

   Enrolling is only half of it. `sbctl status` can report `Setup Mode:
   Disabled` and `Secure Boot: Disabled` together, which means the keys went in
   but the firmware is not checking them. Turn Secure Boot on in the firmware
   and read the status again:

   ```
   sbctl status      # want Secure Boot: ✓ Enabled
   ```

   **Do the PCR 7 bind in step 5 of the install only after this reads
   Enabled.** PCR 7 measures the secure boot state, which covers the enrolled
   keys **and** whether secure boot is switched on. Each of those two changes
   moves PCR 7 and stops the TPM releasing the pool key. A pool bound while
   secure boot is off stops booting the moment it is turned on, and the way
   back is the installer.

   Leave the Microsoft KEK and db entries where they are. On this board they
   are what lets an add-in card run its option ROM, and removing them is a
   known way to lose video or an HBA at POST.

6. Build the certificate authority for the `.nix` zone. The root private key is
   made on the YubiKey and never leaves it. OpenBao holds an intermediate, so
   argama issues its own certificates every day and the root only comes out
   when the intermediate needs signing again.

   PIV starts at the factory defaults, and all three of them are public. The
   PIN is `123456` and the PUK is `12345678`, which are **different values**.
   Three wrong PINs block the applet. Change all three first. `--protect` keeps
   the new management key on the card behind the PIN, so there is no long hex
   string to keep:

   ```
   ykman piv access change-management-key --generate --protect
   ykman piv access change-pin      # from 123456
   ykman piv access change-puk      # from 12345678
   ```

   gpg takes the reader whenever it wakes, and the PIV tools then fail with
   "Error in PCSC call" or simply hang. Run this before each PIV command:

   ```
   gpgconf --kill scdaemon
   ```

   If the PIN does block, `ykman piv reset` costs nothing while PIV is empty.
   It clears the PIV applet alone. The OpenPGP key that opens the pool escrow
   and the OTP slot that answers the ZFS challenge are separate applets and do
   not change.

   ```
   # Root key on the YubiKey, PIV slot 9c. This key cannot be exported.
   # -V, or the root expires in 365 days.
   yubico-piv-tool -s 9c -a generate -o rootpub.pem
   yubico-piv-tool -s 9c -a verify-pin -a selfsign-certificate \
     -S '/CN=argama.nix Root/' -V 7300 -i rootpub.pem -o root.crt

   # OpenBao holds the intermediate that does the daily work.
   bao secrets enable pki
   bao secrets tune -max-lease-ttl=87600h pki
   bao write -field=csr pki/intermediate/generate/internal \
     common_name="argama.nix Intermediate" key_type=ec key_bits=384 > inter.csr
   ```

   Now the YubiKey signs that CSR. `yubico-piv-tool` cannot do this. Both
   `selfsign-certificate` and `request-certificate` work on the card's **own**
   key, so neither one signs somebody else's request. The tool has no action
   that makes the card behave as a certificate authority.

   OpenSSL does it through PKCS#11. `libykcs11.so` already ships in the
   `yubico-piv-tool` package, and OpenSSL 3 reaches it through a provider:

   ```
   YKCS11=$(dirname $(dirname $(readlink -f $(command -v yubico-piv-tool))))/lib/libykcs11.so
   nix shell nixpkgs#pkcs11-provider nixpkgs#openssl
   gpgconf --kill scdaemon
   ```

   OpenSSL looks for a provider only below its own store path, and this one is
   in another. `nix shell` sets PATH and changes nothing about `dlopen`, so
   every command below needs `-provider-path`. Give it before `-provider`,
   because the path must be known when the provider loads:

   ```
   PROV=$(nix build --no-link --print-out-paths nixpkgs#pkcs11-provider)
   ls "$PROV/lib/ossl-modules"      # pkcs11.so
   ```

   Take `openssl` from the same `nix shell` as the provider. The provider is
   built against one OpenSSL, and a pair that does not match fails in a way
   that reads like a missing file.

   Ask the card which objects it holds. Take the URI from this output rather
   than writing one, because the name depends on the ykcs11 version:

   ```
   PKCS11_PROVIDER_MODULE=$YKCS11 openssl storeutl \
     -provider-path "$PROV/lib/ossl-modules" \
     -provider pkcs11 -provider default -keys 'pkcs11:'
   ```

   Slot 9c shows as something near "Private key for Digital Signature". Sign
   with it. The extensions matter: a certificate with no `CA:TRUE` cannot sign,
   and `pathlen:0` stops the intermediate making more authorities below it:

   ```
   cat > ca.ext <<'EOF'
   basicConstraints=critical,CA:TRUE,pathlen:0
   keyUsage=critical,keyCertSign,cRLSign
   subjectKeyIdentifier=hash
   EOF

   PKCS11_PROVIDER_MODULE=$YKCS11 openssl x509 -req \
     -provider-path "$PROV/lib/ossl-modules" \
     -provider pkcs11 -provider default \
     -in inter.csr -CA root.crt -CAkey '<the URI from storeutl>' \
     -days 3650 -CAcreateserial -extfile ca.ext -out inter.crt
   ```

   ```
   bao write pki/intermediate/set-signed certificate=@inter.crt
   bao write pki/roles/argama allowed_domains=argama.nix \
     allow_subdomains=true allow_bare_domains=true max_ttl=720h
   ```

   OpenBao can also make its own root, which needs no card and no PKCS#11:

   ```
   bao write -field=certificate pki/root/generate/internal \
     common_name="argama.nix Root" ttl=87600h key_type=ec key_bits=384 > root.crt
   ```

   That gives up the part where the root key cannot be copied off the machine.
   Swapping the root later costs one file on each client, because
   `secret/argama/ca` is the only place they read it from.

7. Put the root certificate into OpenBao, so the clients can fetch it:

   ```
   bao kv put secret/argama/ca certificate=@root.crt
   ```

8. Add a restic account for each machine that backs up here, then put its
   repository address and password in OpenBao:

   ```
   sudo -u restic htpasswd -B /var/lib/restic/.htpasswd <machine>
   bao kv put secret/<machine>/restic \
     repository=rest:https://<machine>:<pass>@backup.argama.nix/ \
     password=<repository password>
   ```

   Two different passwords appear here. `htpasswd` sets the one that opens the
   HTTP connection, which goes in the repository address. `password` is the one
   that encrypts the repository, which the server never learns. Give them
   different values.

   The file belongs to the restic user with mode 0700, so the command needs
   `sudo -u restic`. Until a machine has a line in this file, the server answers
   every one of its requests with 401 Unauthorized.

9. Make a policy and an AppRole for each client. `argama-issue-approle` only
   reads a role that is already there, so this step comes first. It answers
   `No value found at auth/approle/role/<machine>/role-id` otherwise.

   A client reads the root certificate, which every machine shares, and its own
   restic repository, which no other machine may see. It signs its host key,
   and it signs one client key for each role in `ross.sshCa.clientCerts`. Drop
   the last line on a machine that has no service account:

   ```
   machine=hizack-b

   bao policy write "$machine" - <<EOF
   path "secret/data/argama/ca"             { capabilities = ["read"] }
   path "secret/data/$machine/*"            { capabilities = ["read"] }
   path "ssh-host-signer/sign/host"         { capabilities = ["update"] }
   path "ssh-client-signer/sign/nixremote"  { capabilities = ["update"] }
   EOF

   bao write "auth/approle/role/$machine" \
     token_policies="$machine" \
     token_ttl=1h token_max_ttl=24h \
     secret_id_num_uses=0 secret_id_ttl=0
   ```

   The secret ID must not expire or burn after one use, for the reason in step
   4. `secret/data/$machine/*` gives a machine its own repository and nothing
   else, so a machine an attacker takes cannot read another machine's backup.

   argama itself needs the same two signer lines. Its policy already exists, so
   read it, add them, and write it back rather than replacing it:

   ```
   bao policy read argama > /tmp/argama.hcl
   cat >> /tmp/argama.hcl <<'EOF'
   path "ssh-host-signer/sign/host"            { capabilities = ["update"] }
   path "ssh-client-signer/sign/resticremote"  { capabilities = ["update"] }
   EOF
   bao policy write argama /tmp/argama.hcl && rm /tmp/argama.hcl
   ```

10. Give each client its AppRole. The secret ID travels inside a single use
   token, so an intercepted token arrives already spent and the theft shows:

   ```
   argama-issue-approle <machine>
   ```

   On that machine, unwrap it into `/var/lib/vault-agent/`.

11. Confirm the VPN confinement works:

   ```
   ip netns exec mullvad curl https://am.i.mullvad.net/connected
   ```

## SSH certificate authorities

Two mounts. One signs the keys of people, the other signs the host keys of
machines. They stay apart, because an authority that could do both would let
whoever took it pretend to be argama to every machine you own.

```
bao secrets enable -path=ssh-client-signer ssh
bao write ssh-client-signer/config/ca generate_signing_key=true

bao secrets enable -path=ssh-host-signer ssh
bao write ssh-host-signer/config/ca generate_signing_key=true
```

Put both public halves in the repository. They are public, so git is the right
place, and a machine can then trust the fleet before it has met argama:

```
bao read -field=public_key ssh-client-signer/config/ca > certs/ssh-user-ca.pub
bao read -field=public_key ssh-host-signer/config/ca > certs/ssh-host-ca.pub
```

One role for people. Twelve hours, because you renew it by logging in again:

```
bao write ssh-client-signer/roles/ross - <<'EOF'
{
  "key_type": "ca",
  "allow_user_certificates": true,
  "allowed_users": "ross,root",
  "default_user": "ross",
  "ttl": "12h",
  "default_extensions": {
    "permit-pty": "",
    "permit-agent-forwarding": ""
  }
}
EOF
```

`default_extensions` is a map and not a list. The `key=value` form of `bao
write` makes every value a string, so a map field always fails there with
`expected type 'map[string]interface {}'`. A single `-` reads the whole request
as JSON from standard input instead, which keeps the types.

One role for each service account. Thirty days, because these run with nobody
present. The private key stays on disk and only the certificate is renewed, so
OpenBao must stay sealed for a month before a build or a backup fails:

```
for r in nixremote resticremote; do
  bao write ssh-client-signer/roles/$r - <<EOF
{
  "key_type": "ca",
  "allow_user_certificates": true,
  "allowed_users": "$r",
  "default_user": "$r",
  "ttl": "720h",
  "default_extensions": { "permit-pty": "" }
}
EOF
done
```

One role for host keys. The principals come from the request, which
`modules/ssh-ca.nix` builds from `ross.sshCa.hostPrincipals`:

```
bao write ssh-host-signer/roles/host \
  key_type=ca \
  allow_host_certificates=true \
  allowed_domains="argama,zeta3a,hizack-b,nix,tailde5a8.ts.net" \
  allow_bare_domains=true \
  allow_subdomains=true \
  ttl=720h
```

The list holds four kinds of name. The three machine names cover `ssh argama`,
which needs `allow_bare_domains`. `nix` covers `argama.nix`, and
`tailde5a8.ts.net` covers `argama.tailde5a8.ts.net`, both of which need
`allow_subdomains`. A name that is not here cannot be signed, and a name that
is not signed cannot be dialled once the machine has a certificate.

No address is in the list. The machines take their addresses from DHCP, so a
certificate could not follow one. `ssh 192.168.1.163` stops working on a
machine that has a host certificate. Use the KVM or the serial console when a
name does not resolve.

Each machine signs with the AppRole it already holds for restic, so the two
signer paths are part of the machine policy in step 9 of the setup above.
`bao policy write` replaces a policy and does not add to it, so do not write a
second policy with only these lines. That would take the restic paths away and
stop the backup.

argama signs `resticremote` in place of `nixremote`, and zeta3a signs neither,
so each machine gets only the lines it needs.

### Turning host certificates on

Make the first certificate by hand, before the first rebuild. `nixos-rebuild
switch` restarts sshd, `HostCertificate` is set as soon as `ross.sshCa.hostCert`
is on, and sshd refuses to start when that file is not there. Nothing orders
`ssh-host-cert.service` in front of that restart, and nothing can, because the
unit needs an unsealed OpenBao while sshd must start at every boot.

On the machine, with the principals from its own `ross.sshCa.hostPrincipals`:

```
sudo install -d -m 0755 /var/lib/ssh-host-cert

bao write -field=signed_key ssh-host-signer/sign/host \
  public_key=@/etc/ssh/ssh_host_ed25519_key.pub \
  cert_type=host \
  valid_principals="argama,argama.nix,argama.tailde5a8.ts.net" \
  | sudo tee /var/lib/ssh-host-cert/ssh_host_ed25519_key-cert.pub > /dev/null

ssh-keygen -L -f /var/lib/ssh-host-cert/ssh_host_ed25519_key-cert.pub
```

Read the `Principals` line and check every name you dial is there. Then rebuild
and confirm sshd took it:

```
sudo sshd -T | grep -i hostcertificate
ssh -v argama true 2>&1 | grep -i "host certificate\|Server host certificate"
```

Keep the session you already have open until a second one succeeds. From then
on `ssh-host-cert.service` renews daily against a certificate that lives 30
days, so OpenBao can stay sealed for a month before a client refuses argama.

### Getting in from a new device

```
tailscale up
bao login -method=userpass username=ross
argama-ssh-cert
ssh argama
```

`bao login` works on a device that has never met argama, because
`certs/argama-root.crt` is in the repository and `modules/pki.nix` installs it,
so `https://vault.argama.nix` is already trusted.

### If SSH stops working

An expired host certificate is the one failure that is not quiet. A client with
a `@cert-authority` line refuses an expired host certificate and does not fall
back to the plain host key, so a machine whose renewal has been failing goes
away from every client at once. Watch the Grafana alert on
`ssh_host_cert_not_after`.

To recover, use the KVM, the serial console or the local login, then:

```
systemctl start ssh-host-cert.service
journalctl -u ssh-host-cert.service -n 50
```

`sshd` also refuses to start when `HostCertificate` names a file that is not
there. So `ross.sshCa.hostCert` must stay off until the mount answers, and the
certificate lives below `/var/lib` where a reboot cannot remove it.

## Notes

- argama runs the same kernel as zeta3a: the `pkgsLLVM` 6.18 build with 64K
  pages and HZ_100. 64K pages are the standard for the Ampere machines here.
- The downloads directory and the library are on one dataset on purpose. Sonarr
  and Radarr make a hard link from the download to the library, and a hard link
  cannot cross a filesystem boundary.
- `pkgs.vault` is overlaid to OpenBao in `secrets.nix`. The agent sidecar asks
  for a binary called `vault`, and OpenBao names its binary `bao`, so the
  overlay supplies the name the sidecar wants. No BUSL licensed binary stays on
  the machine.
- OpenBao uses the Raft backend. Raft can auto unseal against a PKCS#11 token,
  and the package has HSM support, so a TPM token can remove the manual unseal
  later. That is not set up yet.
- **argama receives the backups and keeps none of its own.** That is a decision,
  not an oversight. ZFS snapshots cover a mistake, but a dead pool loses the
  fleet's history.
- The restic server is append only, so a client cannot remove a snapshot even
  from its own repository. A machine that an attacker takes cannot erase its own
  history. Retention therefore runs on argama, in `restic-prune-<machine>`, once
  a week on Sunday at 05:00, using each repository's own password out of
  OpenBao. Keep the `clients` list in `backup.nix` the same as the machines that
  set `ross.backup.enable`.
- **Two different unseals, and only one of them is automatic.** The pools open
  by themselves, because the TPM releases their keys against PCR 7. OpenBao does
  not: the YubiKey is a daily carry, so every reboot needs an operator to run
  `argama-unseal`, which decrypts the shares and unseals in one step. So argama
  reaches a login on its own, and the services that read OpenBao wait. A key
  that stayed in the machine would allow a PKCS#11 auto unseal, but a stolen
  machine would then carry its own key.
- **Secure boot is the same setup as zeta3a**: `lanzaboote` with
  `autoGenerateKeys` and `autoEnrollKeys`, and the keys in `/var/lib/sbctl`.
  They stay on disk on purpose. A signing key on a daily carry YubiKey would
  stop `nixos-rebuild` whenever the key is somewhere else, and argama runs Hydra
  and rebuilds without an operator.
- A client's agent reaches OpenBao at `http://argama:8200` over the tailnet, not
  at `https://vault.argama.nix`. That name carries argama's own signature, and a
  client cannot check it until it holds the certificate it is asking OpenBao
  for. `vault.argama.nix` stays for a browser, which can be told to trust the
  authority once by hand.
- Alertmanager is not set up. It needs a notification target, and a monitoring
  system that alerts nowhere is worse than none. Grafana's own alerting works
  in the meantime.
