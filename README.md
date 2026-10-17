
An attempt at making the e-ID testing a bit less painful

# Usage

Just run `run.sh` (or `packer init . && packer build .`, it's basically the same thing for now).

# Development

This project should be pretty straight-forward to understand.

If you want to add a new package to install from the default `apt` repos, go to `http_files/preseed.cfg` and add it to the `d-i pkgsel/include` list

The rest of the setup is handled by the provisioning scripts, which are called from `provisioning_files/setup_infra.sh` (well, that's the plan at least)

If you change `http_files/provisioning/issuer/visconid_vct_metadata.json` (or the issuer's `external-url`), update `vct_metadata_uri#integrity` in `visconid_issuer_metadata.json` too, or the wallet rejects the credential as invalid. The hash must be computed over the metadata as served by the issuer (with `${external-url}` already replaced), not over the file:

```
curl -sk https://viscon.swiyu/issuer/oid4vci/vct/my-vct-v01 | openssl dgst -sha256 -binary | base64
```

If any problem arises (of which I expect many), do not hesitate to contact me: foomanroot@disroot.org