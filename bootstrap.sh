virsh pool-define-as libvirt-pool logical - - /dev/sdd libvirt_pool /dev/libvirt_pool
virsh pool-build libvirt-pool
virsh pool-start libvirt-pool
virsh pool-autostart libvirt-pool

# then to import my debcore base image, I ran 

virsh vol-create-as libvirt-pool debcore_guest_latest_amd64 50G
dd if=debcore_guest_latest_amd64.raw of=/dev/libvirt_pool/debcore_guest_latest_amd64 bs=1M status=progress
