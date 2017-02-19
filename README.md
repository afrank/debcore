# debcore

The idea here is to make a version of linux intended to drive large datacenters. This means easy to deploy, easy to maintain, and does not go down often.

## Testing

### Easy to Deploy
* Very small
* pxe'able

### Easy to Maintain
* dpkg/apt!
* works with ansible and cloud-config

### Does not go down often
* No-reboot upgrades (with apt)
* No release cycle, so you never need to do a dist-upgrade

## Testing

You can build a KVM image for testing like so:
```
./create-image.sh /var/lib/libvirt/images/debian-minimal.qcow2 debian-minimal unstable
```
Here's a sample libvirt xml:
```
<domain type='kvm'>
  <name>debian-minimal</name>
  <memory unit='KiB'>524288</memory>
  <currentMemory unit='KiB'>524288</currentMemory>
  <vcpu>1</vcpu>
  <os>
    <type arch='x86_64'>hvm</type>
    <boot dev='hd'/>
  </os>
  <features>
    <acpi/>
    <apic/>
  </features>
  <clock offset='utc'/>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>restart</on_crash>
  <pm>
    <suspend-to-mem enabled='no'/>
    <suspend-to-disk enabled='no'/>
  </pm>
  <devices>
    <emulator>/usr/bin/kvm</emulator>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2'/>
      <source file='/var/lib/libvirt/images/debian-minimal.qcow2'/>
      <target dev='vda' bus='virtio'/>
    </disk>
    <interface type='bridge'>
      <source bridge='virbr0'/>
      <model type='virtio'/>
    </interface>
    <serial type='pty'>
      <target port='0'/>
    </serial>
    <console type='pty'>
      <target type='serial' port='0'/>
    </console>
    <input type='mouse' bus='ps2'/>
    <input type='keyboard' bus='ps2'/>
    <graphics type='vnc' port='-1' autoport='yes'>
      <listen type='address' address='0.0.0.0'/>
    </graphics>
    <video>
      <model type='cirrus' vram='16384' heads='1' primary='yes'/>
    </video>
    <memballoon model='virtio'/>
  </devices>
</domain>
```
You can try running the image with that xml by running:
```
virsh create debian-minimal.xml
```
