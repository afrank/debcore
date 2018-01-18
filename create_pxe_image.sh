#!/bin/bash

# Much of this is ripped off from http://www.espenbraastad.no/posts/centos-7-rootfs-on-tmpfs/

set -e

img=$1

tmpdir=/tmp/dir$RANDOM

mkdir -p $tmpdir/initramfs/bin
mkdir -p $tmpdir/newroot
mkdir -p $tmpdir/result

guestfish --ro -a $img -i copy-out / $tmpdir/newroot/

echo > $tmpdir/newroot/etc/fstab

wget -O $tmpdir/initramfs/bin/busybox https://www.busybox.net/downloads/binaries/1.26.1-defconfig-multiarch/busybox-x86_64
chmod +x $tmpdir/initramfs/bin/busybox

cat > $tmpdir/initramfs/init << EOF
#!/bin/busybox sh

# Dump to sh if something fails
error() {
  echo "Jumping into the shell..."
  setsid cttyhack sh
}

# Populate /bin with binaries from busybox
/bin/busybox --install /bin

mkdir -p /proc
mount -t proc proc /proc

mkdir -p /sys
mount -t sysfs sysfs /sys

mkdir -p /sys/dev
mkdir -p /var/run
mkdir -p /dev

mkdir -p /dev/pts
mount -t devpts devpts /dev/pts

# Populate /dev
echo /bin/mdev > /proc/sys/kernel/hotplug
mdev -s

mkdir -p /newroot
mount -t tmpfs -o size=1500m tmpfs /newroot || error

echo "Extracting rootfs... "
xz -d -c -f rootfs.tar.xz | tar -x -f - -C /newroot || error

mount --move /sys /newroot/sys
mount --move /proc /newroot/proc
mount --move /dev /newroot/dev

exec switch_root /newroot /sbin/init || error
EOF

chmod +x $tmpdir/initramfs/init

cd $tmpdir/newroot
tar cJf $tmpdir/initramfs/rootfs.tar.xz .

cd $tmpdir/initramfs
find . -print0 | cpio --null -ov --format=newc | gzip -9 > $tmpdir/result/initramfs.gz

cp $tmpdir/newroot/boot/vmlinuz-* $tmpdir/result/

echo $tmpdir/result/
ls -la $tmpdir/result/
