# Zeta 3A

Replaces La Vie en Rose

## Opening zpool

The pool key lives on the TPM, sealed against PCR 7, which is the state of
secure boot. There are three ways in, and each one covers what the one above it
cannot.

| Way                  | Needs                          | When                          |
| -------------------- | ------------------------------ | ----------------------------- |
| PCR 7, no passphrase | the TPM, secure boot unchanged  | every ordinary boot           |
| the sealed passphrase | the TPM and a YubiKey          | after secure boot keys change |
| the backup key file  | a YubiKey only                  | the TPM or the board is gone  |

ZFS holds one wrapping key and no more, so these are not three ZFS credentials.
The first two are two ways to open the same sealed object on the TPM, and the
third is a copy of the key itself, kept away from this machine.

### The passphrase

It is the answer the YubiKey gives to a fixed challenge. The challenge is not a
secret, but it is needed, and the passphrase cannot be worked out without it:

```
ykchalresp -2 "zeta3a-zpool-2026"
```

Both YubiKeys carry the same secret in slot 2, so either one answers. Confirm
that with the same challenge on each, which must give the same answer.

The key loading unit is a `oneshot` with no standard input, so this passphrase
never asks for itself during a boot. Use it from the rescue shell, where a
terminal is attached:

```
zfs-tpm2-load-key zpool
```

### The backup key file

`zpool.key.gpg`, encrypted to the YubiKey OpenPGP key `9F167124D5EC917E`. Keep
it away from this machine, because a copy that burns with the machine protects
against nothing. From any rescue system:

```
gpg --decrypt zpool.key.gpg | zfs load-key zpool
```

It must be 32 bytes when it opens. Anything else means the file is wrong.

### Before touching the secure boot firmware

Enrolling or clearing the secure boot keys changes PCR 7, and the first way in
above stops working. The passphrase still opens it, so this is a nuisance and
not a loss, but the ordinary boot will stop until the key is sealed again:

```
zfs-tpm2-change-key -b /root/zpool.key -P sha256:7 -A zpool
```

That makes a **new** key, so the old backup file dies the moment it runs. Make a
new one, check that it opens to 32 bytes, and only then destroy the old.
