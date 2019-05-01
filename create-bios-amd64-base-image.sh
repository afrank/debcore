#!/bin/bash

# borrowed from https://gist.github.com/spectra/10301941
# and http://diogogomes.com/2012/07/13/debootstrap-kvm-image/

INCLUDES=${INCLUDES:="openssh-server,init,curl,vim,locales-all,less,dmidecode,iputils-ping,fping,tcpdump,rsync,ethtool,iproute2,net-tools,sudo,vim,gnupg,iptables,apt-utils,apt-transport-https"}
#INCLUDES=${INCLUDES:="openssh-server,init,curl,vim,locales-all,less,dmidecode,iputils-ping,sudo,iproute2,tcpdump,apt-utils,net-tools,ipmitool"}
MIRROR=${MIRROR:="http://mirrors.kernel.org/debian"}
IMGSIZE=${IMGSIZE:=8G}

clean_debian() {
	[ "$MNT_DIR" != "" ] && chroot $MNT_DIR umount /proc/ /sys/ /dev/ /boot/
	sleep 1s
	[ "$MNT_DIR" != "" ] && umount $MNT_DIR
	sleep 1s
	[ "$DISK" != "" ] && qemu-nbd -d $DISK
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

FILE=$1
HOSTNAME=debcore1
shift 3

trap cancel INT

echo "Installing debcore into $FILE..."

MNT_DIR=`tempfile`
rm $MNT_DIR
mkdir $MNT_DIR
DISK=

if [ ! -f $FILE ]; then
    echo "Creating $FILE"
    qemu-img create -f qcow2 $FILE $IMGSIZE
fi

BOOT_PKG="linux-image-amd64 grub-pc"

echo "Looking for nbd device..."

modprobe nbd max_part=16 || fail "failed to load nbd module into kernel"

for i in /dev/nbd*; do
  if qemu-nbd -c $i $FILE; then
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

echo "Installing Debcore..."
debootstrap --variant=minbase --include=$INCLUDES unstable $MNT_DIR $MIRROR || fail "cannot install debcore into $DISK"

# NOTE: if you're applying this directly to a physical disk you should change this to sda
echo "Configuring system..."
cat <<EOF > $MNT_DIR/etc/fstab
/dev/vda1 /boot               ext4    sync 0       2
/dev/vda2 /                   ext4    errors=remount-ro 0       0
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

[[ -d $MNT_DIR/etc/systemd/network ]] || mkdir -p $MNT_DIR/etc/systemd/network

cat <<EOF > $MNT_DIR/etc/systemd/network/en.network
[Match]
Name=en*
[Network]
DHCP=ipv4
EOF

cat <<EOF > $MNT_DIR/etc/systemd/network/en.link
[Link]
MACAddressPolicy=persistent
EOF

mount --bind /dev/ $MNT_DIR/dev || fail "cannot bind /dev"
chroot $MNT_DIR mount -t ext4 ${DISK}p1 /boot || fail "cannot mount /boot"
chroot $MNT_DIR mount -t proc none /proc || fail "cannot mount /proc"
chroot $MNT_DIR mount -t sysfs none /sys || fail "cannot mount /sys"

chroot $MNT_DIR adduser --quiet --system --group --no-create-home --home /run/systemd/netif --gecos "systemd Network Management" systemd-network

rm -f $MNT_DIR/etc/apt/sources.list
echo "deb $MIRROR sid main contrib non-free" > $MNT_DIR/etc/apt/sources.list

LANG=C DEBIAN_FRONTEND=noninteractive chroot $MNT_DIR apt update
LANG=C DEBIAN_FRONTEND=noninteractive chroot $MNT_DIR apt install -y $BOOT_PKG || fail "cannot install $BOOT_PKG"
LANG=C DEBIAN_FRONTEND=noninteractive chroot $MNT_DIR apt install -y cloud-init

echo "GRUB_CMDLINE_LINUX='console=tty0 console=ttyS0,115200n8'" >> $MNT_DIR/etc/default/grub
echo "GRUB_TERMINAL=serial" >> $MNT_DIR/etc/default/grub
echo "GRUB_SERIAL_COMMAND=\"serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1\"" >> $MNT_DIR/etc/default/grub
echo "T0:23:respawn:/sbin/getty -L ttyS0 115200 vt100" >> $MNT_DIR/etc/inittab

chroot $MNT_DIR grub-install $DISK || fail "cannot install grub"
chroot $MNT_DIR update-grub || fail "cannot update grub"
chroot $MNT_DIR apt clean || fail "unable to clean apt cache"
chroot $MNT_DIR systemctl enable systemd-networkd || fail "failed to enable systemd-networkd"
cat /dev/null > $MNT_DIR/etc/machine-id

sed -i "s|${DISK}p|/dev/vda|g" $MNT_DIR/boot/grub/grub.cfg

#echo PermitRootLogin yes >> $MNT_DIR/etc/ssh/sshd_config
mkdir -p $MNT_DIR/root/.ssh
echo ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDd7rLlS1NmTpBr5KP5ryuA/euGD8I6uc2RCg4sCIlvH0FhEPb123QuMVImHi23ftVP61cKZXm8MlTtAoLHduYtGMHCkJWAAkiIpPetAP2KPIpuadtgIS8xuD/TCYjl0xNXLh0M1C7i7HOnTd8yr+3QNjUppyDdKjLvMQbPWZZTU5rt7CYoGlrxHjieCkq9jj8kRjRARUaAJ4DHEgMFUDIcq3JYluzzkgPK/JFwoq/IokVQCr5qfQRwr3SCkD4sIuGTj+J67uzabIr/xDBqlrMW3T+7YfY12ciHpijob+l7xESkJ+6Gxh56z8llBkGiVyh3UqnmW4MvfuAA/D3Dzhwr afrank@adams-mbp.lan > $MNT_DIR/root/.ssh/authorized_keys

echo 'root:$6$5/3MhxNf$VTKmL2ISOVm6MlLyyK/bvQgxVMrlRVQwi/xa5.HrOeMidTHXFpjaBn.5budlJcamZJGoYz.Iq25VJ7HBmzw6U0' | chroot $MNT_DIR chpasswd --encrypted root

#echo "Enter root password:"
#while ! chroot $MNT_DIR passwd root
#do
#	echo "Try again"
#done

echo "Finishing grub installation..."
grub-install $DISK --root-directory=$MNT_DIR --modules="biosdisk part_msdos" || fail "cannot reinstall grub"

echo "SUCCESS!"
clean_debian
exit 0

