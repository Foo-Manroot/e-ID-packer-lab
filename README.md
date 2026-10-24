
An attempt at making the e-ID testing a bit less painful

# Usage

Just run `run.sh` (or `packer init . && packer build .`, it's basically the same thing for now).

You need Packer >= 1.7 (the template uses HCL2 and `packer init`). Beware of the `packer` snap, which is stuck at v1.0.0; install it from HashiCorp's repos instead: https://developer.hashicorp.com/packer/install

Choose your hypervisor by setting `hypervisor` in `variables.auto.pkrvars.hcl`: `parallels`, `vmware` or `qemu`.

## Without VMware/Parallels: QEMU/KVM

On GNU/Linux you can build and run the VM with QEMU/KVM instead, no VMware account needed.

1. Install QEMU (`apt install qemu-system-x86 qemu-utils`) and make sure your user can access `/dev/kvm`
2. Set `hypervisor = "qemu"` in `variables.auto.pkrvars.hcl` and run `run.sh`. The image ends up in `output-eID/eID_testlab.qcow2`
3. Start the VM with `start-qemu.sh`. It runs on a copy-on-write overlay (`output-eID/eID_testlab-run.qcow2`), so you can delete the overlay to go back to the freshly built VM

The VM uses QEMU's user-mode networking, so it's not reachable by its own IP. Instead, `start-qemu.sh` forwards SSH to `127.0.0.1:2222` and HTTPS to `127.0.0.1:8443`. Since all DIDs reference https://viscon.swiyu (port :443 is implicit), you can either change all DIDs (and recalculate the integrity hashes) or add a redirector from 127.1:443 to 127.1:8443 (which would need sudo):

```
sudo socat TCP-LISTEN:443,bind=127.0.0.1,reuseaddr,fork TCP:127.0.0.1:8443
```

Then, in Burp's DNS override, point `viscon.swiyu` to `127.0.0.1`.

Bridged networking is not needed: Burp runs on the host, and both the emulator and a physical phone (via `adb reverse`) send their traffic through Burp.

# Development

This project should be pretty straight-forward to understand.

If you want to add a new package to install from the default `apt` repos, go to `http_files/preseed.cfg` and add it to the `d-i pkgsel/include` list

The rest of the setup is handled by the provisioning scripts, which are called from `provisioning_files/setup_infra.sh` (well, that's the plan at least)

If you change `http_files/provisioning/issuer/visconid_vct_metadata.json` (or the issuer's `external-url`), update `vct_metadata_uri#integrity` in `visconid_issuer_metadata.json` too, or the wallet rejects the credential as invalid. The hash must be computed over the metadata as served by the issuer (with `${external-url}` already replaced), not over the file:

```
curl -sk https://viscon.swiyu/issuer/oid4vci/vct/my-vct-v01 | openssl dgst -sha256 -binary | base64
```

This also applies to the other VCT metadata files:
  - `visconid_issuer_metadata.json` references the VCT metadata (`visconid_vct_metadata.json`)
  - `visconid_vct_metadata.json` references the JSON schema (`visconid_json_schema.json`) and OCA definition (`visconid_oca.json`)
  - `visconid_oca.json` references itself (`$.capture_bases[].digest`). More info can be found in [the Swiyu OCA spec](https://swiyu-admin-ch.github.io/specifications/oca-v1-0/#cesr-hash-creation-example-of-an-oca-bundle)

Careful with trailing newlines: they are part of the hash, and the hashed files (VCT metadata, JSON schema and OCA) don't end with one. Some editors add it on save.

If any problem arises (of which I expect many), do not hesitate to contact me: foomanroot@disroot.org