#!/bin/bash

# borrowed from https://gist.github.com/spectra/10301941
# and http://diogogomes.com/2012/07/13/debootstrap-kvm-image/

# Configs overwritable via environment variables
VSYSTEM=${VSYSTEM:=qemu}					# Either 'qemu' or 'kvm'
FLAVOUR=${FLAVOUR:=debian}					# Either 'debian' or 'ubuntu'
INCLUDES=${INCLUDES:="openssh-server,init"}
MIRROR=${MIRROR:="http://ftp.us.debian.org/debian"}
ARCH=${ARCH:=amd64}
APT_CACHER=${APT_CACHER:=no}
IMGSIZE=${IMGSIZE:=2G}

clean_debian() {
	[ "$MNT_DIR" != "" ] && chroot $MNT_DIR umount /proc/ /sys/ /dev/ /boot/
	sleep 1s
	[ "$MNT_DIR" != "" ] && umount $MNT_DIR
	sleep 1s
	[ "$DISK" != "" ] && $VSYSTEM-nbd -d $DISK
	sleep 1s
	[ "$MNT_DIR" != "" ] && rm -r $MNT_DIR
}

fail() {
	clean_debian
	echo ""
	echo "FAILED: $1"
	exit 1
}

cancel() {
	fail "CTRL-C detected"
}

if [ $# -lt 3 ]
then
	echo "author: Kamil Trzcinski (http://ayufan.eu)"
	echo "license: GPL"
	echo "usage: $0 <image-file> <hostname> <release> [optional debootstrap args]" 1>&2
	exit 1
fi

FILE=$1
HOSTNAME=$2
RELEASE=$3
shift 3

trap cancel INT

echo "Installing $RELEASE into $FILE..."

MNT_DIR=`tempfile`
rm $MNT_DIR
mkdir $MNT_DIR
DISK=

# add apt cacher for faster rebuilds, runs on 3142
if [ "$APT_CACHER" == "yes" ]; then
    echo "Installing apt-cacher-ng for fast rebuilds"
    apt-get install apt-cacher-ng
fi

if [ ! -f $FILE ]; then
    echo "Creating $FILE"
    $VSYSTEM-img create -f qcow2 $FILE $IMGSIZE
fi

if [ $FLAVOUR == "debian" ]; then
    BOOT_PKG="linux-image-$ARCH grub-pc"
elif [ $FLAVOUR == "ubuntu" ]; then
    BOOT_PKG="linux-image-generic grub-pc"
fi

echo "Looking for nbd device..."

modprobe nbd max_part=16 || fail "failed to load nbd module into kernel"

for i in /dev/nbd*
do
	if $VSYSTEM-nbd -c $i $FILE
	then
		DISK=$i
		break
	fi
done

[ "$DISK" == "" ] && fail "no nbd device available"

echo "Connected $FILE to $DISK"

echo "Partitioning $DISK..."
sfdisk $DISK -q << EOF || fail "cannot partition $FILE"
,409600,83,*
;
EOF

echo "Creating boot partition..."
mkfs.ext4 -q ${DISK}p1 || fail "cannot create /boot ext4"

echo "Creating root partition..."
mkfs.ext4 -q ${DISK}p2 || fail "cannot create / ext4"

echo "Mounting root partition..."
mount ${DISK}p2 $MNT_DIR || fail "cannot mount /"

echo "Installing Debian $RELEASE..."
#debootstrap --include=$INCLUDES $* $RELEASE $MNT_DIR $MIRROR || fail "cannot install $RELEASE into $DISK"
debootstrap --variant=minbase --include=$INCLUDES $* $RELEASE $MNT_DIR $MIRROR || fail "cannot install $RELEASE into $DISK"

echo "Configuring system..."
cat <<EOF > $MNT_DIR/etc/fstab
/dev/vda1 /boot               ext4    sync 0       2
/dev/vda2 /                   ext4    errors=remount-ro 0       1
EOF

echo $HOSTNAME > $MNT_DIR/etc/hostname

cat <<EOF > $MNT_DIR/etc/hosts
127.0.0.1       localhost
127.0.1.1 		$HOSTNAME
# The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF

#cat <<EOF > $MNT_DIR/etc/network/interfaces
#auto lo
#iface lo inet loopback
#auto eth0
#iface eth0 inet dhcp
#EOF

[[ -d $MNT_DIR/etc/systemd/network ]] || mkdir -p $MNT_DIR/etc/systemd/network

cat <<EOF > $MNT_DIR/etc/systemd/network/en.network
[Match]
Name=en*

[Network]
DHCP=ipv4
EOF

mount --bind /dev/ $MNT_DIR/dev || fail "cannot bind /dev"
chroot $MNT_DIR mount -t ext4 ${DISK}p1 /boot || fail "cannot mount /boot"
chroot $MNT_DIR mount -t proc none /proc || fail "cannot mount /proc"
chroot $MNT_DIR mount -t sysfs none /sys || fail "cannot mount /sys"
LANG=C DEBIAN_FRONTEND=noninteractive chroot $MNT_DIR apt-get install -y --force-yes -q $BOOT_PKG || fail "cannot install $BOOT_PKG"
chroot $MNT_DIR grub-install $DISK || fail "cannot install grub"
chroot $MNT_DIR update-grub || fail "cannot update grub"
chroot $MNT_DIR apt-get clean || fail "unable to clean apt cache"
chroot $MNT_DIR systemctl enable systemd-networkd || fail "failed to enable systemd-networkd"

sed -i "s|${DISK}p1|/dev/vda1|g" $MNT_DIR/boot/grub/grub.cfg
sed -i "s|${DISK}p2|/dev/vda2|g" $MNT_DIR/boot/grub/grub.cfg

echo "Enter root password:"
while ! chroot $MNT_DIR passwd root
do
	echo "Try again"
done

echo "Finishing grub installation..."
grub-install $DISK --root-directory=$MNT_DIR --modules="biosdisk part_msdos" || fail "cannot reinstall grub"

echo "SUCCESS!"
clean_debian
exit 0
