#!/bin/bash -x

# wget http://snapshots.linaro.org/components/kernel/leg-virt-tianocore-edk2-upstream/latest/QEMU-AARCH64/RELEASE_GCC5/QEMU_EFI.fd

set -e

ARCH=${1:-arm64}
# ARCH=${1:-amd64}

build_rootfs=build/rootfs
build_efi=build/efi
img_name=debcore_${ARCH}_$(date +%F).img
size=20480 # 20GB
MIRROR="https://mirrors.wit.com/debian"
INCLUDES="init,openssh-server,curl,vim,locales-all,less,dmidecode,iputils-ping,iproute2,net-tools,sudo,gnupg"
DIST=sid

DISK=

clean() {
        [ "$build_rootfs" != "" ] && chroot $build_rootfs umount /proc/ /sys/ /dev/ /boot/
        sleep 1s
        [ "$build_rootfs" != "" ] && umount $build_rootfs
        sleep 1s
        [ "$DISK" != "" ] && qemu-nbd -d $DISK
}

fail() {
        clean
        echo ""
        echo "FAILED: $1"
        exit 1
}

cancel() {
        fail "CTRL-C detected"
}

trap cancel INT

if [[ "$ARCH" = "arm64" ]]; then
	SERIAL=ttyAMA0
elif [[ "$ARCH" = "amd64" ]]; then
	SERIAL=ttyS0
else
	echo Unsupported ARCH: $ARCH
	exit 2
fi

[[ -e $img_name ]] && rm -vf $img_name

dd if=/dev/zero of=$img_name bs=1M count=$size conv=sparse

for i in /dev/nbd*; do
  if qemu-nbd -f raw -c $i $img_name; then
    DISK=$i
    break
  fi
done

sgdisk -E $DISK

sgdisk -g -n 15:2048:204800 -t 15:ef00 -n 1:206848 $DISK

mkfs.vfat ${DISK}p15
mkfs.ext4 ${DISK}p1

[[ -d $build_rootfs ]] && rm -rf $build_rootfs
mkdir -p $build_rootfs

[[ -d $build_efi ]] && rm -rf $build_efi
mkdir -p $build_efi

root_fsid=$(blkid ${DISK}p1 | grep -o ' UUID="[^"]\+"' | cut -d\" -f2)

mount ${DISK}p1 $build_rootfs
mount ${DISK}p15 $build_efi

qemu-debootstrap --arch $ARCH --variant=minbase --include=$INCLUDES --components=main,contrib,non-free $DIST $build_rootfs $MIRROR

echo PermitRootLogin yes >> $build_rootfs/etc/ssh/sshd_config

cat <<EOF > $build_rootfs/etc/systemd/system/wit-init.service
[Unit]
Description=WIT System Init
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/wit-init.sh
RemainAfterExit=true
StandardOutput=journal

[Install]
WantedBy=multi-user.target
EOF

cat <<EOF > $build_rootfs/usr/local/bin/wit-init.sh
#!/bin/bash

dmidecode --oem-string 1 | base64 -d | bash

EOF
chmod +x $build_rootfs/usr/local/bin/wit-init.sh

[[ -d $build_rootfs/root/.ssh ]] || mkdir -p $build_rootfs/root/.ssh
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC9ibC48xyLhpfDaWoYvQ/IaPJjDXKkh5g79yh4iGK1WAbBu7QrOo8JmOT0BYXXeOWHEJEWnLLYYrF+QRpOnEhz7LVFo3OL/zZ6lL/IghvFQ3XAtrEZE+10UszT74IU/Kv/KRr5+4IwCh0GrDE2nGvk+4Tmb0L29vd6kHGz5gjdgnIA7hH0nujH9KQAkpFZAWamLCz2pbtc9REM2O/Q7SbAfZFKotnC9QgxirIohRTVGKWqLgkuEwR1uqkstWVJVpmvGgoxSg2Ak+hRRfslLeKLEnWYT540b6JZwvz2o9A1HI96zfNBS+NyG4K2Woa229FulZ88KimstoRgksmBdqhX root@workbot" > $build_rootfs/root/.ssh/authorized_keys

mount --bind /dev $build_rootfs/dev
chroot $build_rootfs mount -t proc none /proc
chroot $build_rootfs mount -t sysfs none /sys

echo deb https://mirrors.wit.com/debcore sid main > $build_rootfs/etc/apt/sources.list.d/debcore.list
curl https://mirrors.wit.com/debcore/public.key | chroot $build_rootfs apt-key add -
chroot $build_rootfs apt update
chroot $build_rootfs apt install -y grub-efi-${ARCH} grub-efi-${ARCH}-bin linux-image-${ARCH}

echo "GRUB_CMDLINE_LINUX=\"console=tty0 console=$SERIAL,115200n8 net.ifnames=0 biosdevname=0\"" >> $build_rootfs/etc/default/grub
echo "GRUB_TERMINAL=serial" >> $build_rootfs/etc/default/grub
echo "GRUB_SERIAL_COMMAND=\"serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1\"" >> $build_rootfs/etc/default/grub
echo "T0:23:respawn:/sbin/getty -L $SERIAL 115200 vt100" >> $build_rootfs/etc/inittab

chroot $build_rootfs grub-mkconfig -o /boot/grub/grub.cfg
chroot $build_rootfs systemctl enable wit-init
chroot $build_rootfs systemctl enable systemd-networkd
chroot $build_rootfs usermod -p '$1$ov9.ZGAy$bTUnP5BXx2j8Nv20chk860' root
chroot $build_rootfs umount /dev /proc /sys

sed -i "s|${DISK}p|/dev/vda|g" $build_rootfs/boot/grub/grub.cfg

# random files from ubuntu cloud image to the rescue!
rsync -a efi-$ARCH/boot/ $build_rootfs/boot/
cp -r efi-$ARCH/efi/* $build_efi/
#rsync -a $build_rootfs/usr/lib/grub/arm64-efi $build_rootfs/boot/grub/

if [[ "$ARCH" = "amd64" ]]; then
	cat > $build_efi/boot/grub/grub.cfg << EOF
search.fs_uuid $root_fsid root hd0,gpt1 
set prefix=(\$root)'/boot/grub'
configfile \$prefix/grub.cfg
EOF
	cp $build_efi/boot/grub/grub.cfg $build_efi/EFI/BOOT/
fi

cat > $build_rootfs/etc/fstab << EOF
/dev/vda1       /               ext4    defaults        0 0
/dev/vda15      /boot/efi       vfat    defaults        0 0
EOF
echo debcore1 > $build_rootfs/etc/hostname
cat <<EOF > $build_rootfs/etc/hosts
127.0.0.1 localhost
127.0.1.1 debcore1
# The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF

clean
echo SUCCESS

# Example qemu syntax:
# qemu-system-aarch64 -m 2048 -cpu host -enable-kvm -M virt,gic_version=3 -bios /home/afrank/arm_stuff/u-boot/u-boot.bin -drive if=none,file=wtf3.img,id=mydisk -device ich9-ahci,id=ahci -device ide-drive,drive=mydisk,bus=ahci.0 -nographic -netdev type=tap,id=net0,script=/etc/qemu-ifup-public,downscript=/etc/qemu-ifdown,ifname=debcore1.0 -device virtio-net-device,netdev=net0,mac=52:55:00:d1:55:01
