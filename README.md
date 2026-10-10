
An attempt at making the e-ID testing a bit less painful

# Usage

Just run `run.sh` (or `packer init . && packer build .`, it's basically the same thing for now).

You need Packer >= 1.7 (the template uses HCL2 and `packer init`). Beware of the `packer` snap, which is stuck at v1.0.0; install it from HashiCorp's repos instead: https://developer.hashicorp.com/packer/install

Choose your hypervisor by setting `hypervisor` in `variables.auto.pkrvars.hcl`: `parallels`, `vmware` or `qemu`.

## Without VMware/Parallels: QEMU/KVM

On GNU/Linux you can build and run the VM with QEMU/KVM instead, no VMware account needed.

1. Install QEMU (`apt install qemu-system-x86 qemu-utils`) and make sure your user can access `/dev/kvm`
2. Set `hypervisor = "qemu"` in `variables.auto.pkrvars.hcl` and run `run.sh`. The image ends up in `output-eID/eID_testlab.qcow2`
3. Start the VM with `start-vm.sh`. It runs on a copy-on-write overlay (`output-eID/eID_testlab-run.qcow2`), so you can delete the overlay to go back to the freshly built VM

The VM uses QEMU's user-mode networking, so it's not reachable by its own IP. Instead, `start-vm.sh` forwards SSH to `127.0.0.1:2222` and HTTPS to `127.0.0.1:443`. Binding port 443 as a normal user needs:

```
sudo sysctl net.ipv4.ip_unprivileged_port_start=443
```

(this resets on reboot). Then, in Burp's DNS override, point `viscon.swiyu` to `127.0.0.1`.

Bridged networking is not needed: Burp runs on the host, and both the emulator and a physical phone (via `adb reverse`) send their traffic through Burp.

# Slides errata

- Slide 38 ("Custom cert pinning"): the network security config is `network_security_config.xml` in this repo. To download it into the wallet:
  ```
  curl -o app/src/abn/res/xml/network_security_config.xml https://raw.githubusercontent.com/Foo-Manroot/e-ID-packer-lab/main/network_security_config.xml
  ```
- Slide 41 ("Going through Burp"): with a physical device, the port forwarded with `adb reverse` must match the proxy port set on the phone. Use `adb reverse tcp:8080 tcp:8080`, then proxy `127.0.0.1:8080` (or `adb shell settings put global http_proxy 127.0.0.1:8080`, and `adb shell settings put global http_proxy :0` to undo it)

# Development

This project should be pretty straight-forward to understand.

If you want to add a new package to install from the default `apt` repos, go to `http_files/preseed.cfg` and add it to the `d-i pkgsel/include` list

The rest of the setup is handled by the provisioning scripts, which are called from `provisioning_files/setup_infra.sh` (well, that's the plan at least)

If any problem arises (of which I expect many), do not hesitate to contact me: foomanroot@disroot.org