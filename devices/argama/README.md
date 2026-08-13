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

Four names do their own checking, each for a reason:

- **Jellyfin.** A forward check works by sending a browser to a login page. A
  television, a phone application or a Chromecast cannot follow that, so
  guarding Jellyfin here would break every client that is not a browser. Its own
  accounts stay the boundary.
- **restic.** It speaks HTTP basic authentication and follows no redirect.
- **OpenBao.** It has its own tokens, and it holds Authelia's secrets, so it must
  answer before Authelia can start.
- **harmonia.** The Nix daemon follows no login redirect. The cache needs no
  login either, since every store path carries a signature.

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

OpenBao keeps a port of its own because trust has to start somewhere. A client's
agent reads argama's certificate authority *from* OpenBao, so it cannot check a
certificate signed by that authority until after it has read it. Tailscale
encrypts that link.

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
    /dev/disk/by-id/wwn-0x5002538ae86338d0

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

### 5. Give the pool keys to the TPM, and keep a way back

Do this after the first boot, from the installed system. It replaces each
passphrase with a key that the TPM holds, so stage 1 opens both pools without
asking.

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

```
sudo env TZPFMS_PASSPHRASE_HELPER='ykchalresp -2 argama-zpool-2026' \
  zfs-tpm2-change-key -b /root/zpool.key -P sha256:7 -A zpool

sudo env TZPFMS_PASSPHRASE_HELPER='ykchalresp -2 argama-tank-2026' \
  zfs-tpm2-change-key -b /root/tank.key -P sha256:7 -A tank
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
sudo cat /root/zpool.key | gpg --encrypt --recipient 9F167124D5EC917E \
  --trust-model always --output ~/zpool.key.gpg
sudo cat /root/tank.key  | gpg --encrypt --recipient 9F167124D5EC917E \
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
sudo shred -u /root/zpool.key /root/tank.key
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

   ```
   export BAO_ADDR=http://127.0.0.1:8200
   gpg --export <your key id> | base64 > /tmp/yk.pub
   bao operator init -key-shares=1 -key-threshold=1 \
     -pgp-keys=/tmp/yk.pub -root-token-pgp-key=/tmp/yk.pub
   ```

   Put each encrypted share in `/var/lib/openbao/unseal-shares/` with an `.asc`
   name. Then unseal with the YubiKey in the machine:

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
   secret ID to the two paths in the table above.

5. Enroll the secure boot keys. `lanzaboote` makes and enrolls them, but the
   firmware must be in secure boot setup mode first. Check the result with
   `sbctl status`, the same as on zeta3a. These keys stay on disk, and the note
   below says why the YubiKey does not hold them.

6. Build the certificate authority for the `.nix` zone. The root private key is
   made on the YubiKey and never leaves it. OpenBao holds an intermediate, so
   argama issues its own certificates every day and the root only comes out
   when the intermediate needs signing again.

   ```
   # Root key on the YubiKey, PIV slot 9c. This key cannot be exported.
   yubico-piv-tool -s 9c -a generate -o rootpub.pem
   yubico-piv-tool -s 9c -a verify-pin -a selfsign-certificate \
     -S '/CN=argama .nix root/' -i rootpub.pem -o root.crt

   # OpenBao holds the intermediate that does the daily work.
   bao secrets enable pki
   bao secrets tune -max-lease-ttl=8760h pki
   bao write -field=csr pki/intermediate/generate/internal \
     common_name="argama .nix intermediate" > inter.csr

   # The YubiKey signs it. This is the only step that needs the key.
   yubico-piv-tool -s 9c -a verify-pin -a request-certificate \
     -i inter.csr -o inter.crt

   bao write pki/intermediate/set-signed certificate=@inter.crt
   bao write pki/roles/argama allowed_domains=argama.nix \
     allow_subdomains=true allow_bare_domains=true max_ttl=720h
   ```

7. Put the root certificate into OpenBao, so the clients can fetch it:

   ```
   bao kv put secret/argama/ca certificate=@root.crt
   ```

8. Add a restic account for each machine that backs up here, then put its
   repository address and password in OpenBao:

   ```
   htpasswd -B /var/lib/restic/.htpasswd <machine>
   bao kv put secret/<machine>/restic \
     repository=rest:https://<machine>:<pass>@backup.argama.nix/ \
     password=<repository password>
   ```

9. Give each client its AppRole. The secret ID travels inside a single use
   token, so an intercepted token arrives already spent and the theft shows:

   ```
   argama-issue-approle <machine>
   ```

   On that machine, unwrap it into `/var/lib/vault-agent/`.

10. Confirm the VPN confinement works:

   ```
   ip netns exec mullvad curl https://am.i.mullvad.net/connected
   ```

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
