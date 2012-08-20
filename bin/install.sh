#!/bin/sh -e

# Install freebsd to a USB flash device (CF, memstick etc.)




# FUNCTIONS

# check if running as root
root_check() {
    if [ `whoami` != "root" ]; then
        echo "Sorry `whoami`, must run as root." 
        exit 1
    fi
}

# download FreeBSD release files to $dist
fetch_release() {
    mkdir -p $release_path
    cd $release_path

    for distrubution in $distributions; do 
	$FETCH -a $freebsd_mirror/pub/FreeBSD/releases/i386/$release/$distrubution.txz 
    done

    cd $working_dir
}

# fetch custom kernel from the network if $custom_kernel is a url
fetch_custom_kernel() {

    protocol=`echo $custom_kernel | awk  -F':' '{print $1}'`

    if [ "x$protocol" = 'xhttp' ] || [  "x$protocol" = 'xftp' ]; then

	kernel_basename=`basename $custom_kernel`
	custom_kernel_local_path="${release_path}/${kernel_basename}"

	# Check if custom kernel exists and fetch if it doesn't
	if [ ! -f $custom_kernel_local_path ]; then
	    echo "=> Fetching custom kernel to $dist"
	    cd $release_path
	    $FETCH -a $custom_kernel
	    cd $working_dir
	fi

	custom_kernel=$custom_kernel_local_path

    else

	# assume it's a local file
	if [ ! -f "$custom_kernel" ]; then
	    echo "=> Unable to find custom kernel: $custom_kernel"
	    exit 2
	fi

    fi

}

partition_and_mount() {
    echo "=> Partitioning CF card $cf_device"

    if ! [ -c "/dev/${cf_device}" ]; then
	echo "Error: /dev/${cf_device} is not a block device"
	exit 1
    fi
    if /sbin/gpart show $cf_device > /dev/null 2> /dev/null; then
	echo "Error: /dev/${cf_device} already contains a partition table."
	echo ""
	/sbin/gpart show $cf_device
	echo "You may erase the partition table manually with: destroy_geom.sh -d $cf_device"
	exit 1
    fi

    $GPART create -s GPT $cf_device
    $GPART add -t freebsd-boot -s 128 $cf_device
    $GPART add -t freebsd-ufs $cf_device
    echo "=> Creating file system"
    $NEWFS -L root /dev/${cf_device}p2
    echo "=> Mounting as $cf_mount_point"
    $MOUNT /dev/${cf_device}p2 $cf_mount_point
}

install_bootcode() {
    echo "=> Installing boot code"
    $GPART bootcode -b $cf_mount_point/boot/pmbr -p $cf_mount_point/boot/gptboot -i 1 $cf_device
}

# install FreeBSD distribution set
install_dist() {
    dist_file=$1.txz
    echo "=> Extracting $dist_file to $cf_mount_point"
    tar --unlink -xpzf $release_path/$dist_file -C ${cf_mount_point:-/}
}

install_custom_kernel() {
    echo "=> Extracting `basename $custom_kernel` to $cf_mount_point"
    tar --unlink -xpzf $custom_kernel -C ${cf_mount_point:-/}
}

set_hostname() {
    file="$cf_mount_point/etc/rc.conf"
    echo "=> Setting hostname to $hostname"
    echo "hostname=\"$hostname\"" >> $file
}

set_dhcp_if() {
    file="$cf_mount_point/etc/rc.conf"

    if [ ! "$dhcp_if" = 'false' ]; then
	echo "=> Setting DHCP interface to $dhcp_if"
	echo "ifconfig_${dhcp_if}=\"DHCP\"" >> $file
    fi
}

install_config() {
    echo "=> Copying initial configuration"

    if [ ! -d  $config_dir ]; then
	echo "ERROR: $config_dir not a directory. quitting"
	exit 3
    fi

    cp -av $config_dir/* $cf_mount_point/
    chmod -v 0755 "$cf_mount_point/etc/rc.d/link_var"
}

prep_var_for_tmpfs() {
    echo "=> Preparing $cf_mount_point/var for tmpfs"

    # persist package database
    mkdir -p $cf_mount_point/usr/var/db
    if [ -d $cf_mount_point/var/db/pkg ]; then
	cp -r $cf_mount_point/var/db/pkg $cf_mount_point/usr/var/db
    fi

    # persist cron
    if [ -d $cf_mount_point/var/cron ]; then
	cp -r $cf_mount_point/var/cron $cf_mount_point/usr/var/
    fi

    # persist named config
    mkdir -p $cf_mount_point/usr/var/named
    if [ -d $cf_mount_point/var/named/etc ]; then
        cp -r $cf_mount_point/var/named/etc $cf_mount_point/usr/var/named/etc
    fi

    # clear /var
    chflags -R noschg $cf_mount_point/var
    rm -rf $cf_mount_point/var/*
}

install_packages() {
    echo "=> Installing packages"
    cp /etc/resolv.conf $cf_mount_point/etc/
    release_downcase=`echo $release | tr '[:upper:]' '[:lower:]'`

    for package in ${packages}; do 
	echo "==> Installing $package"
	chroot $cf_mount_point sh -c "PACKAGEROOT=$freebsd_mirror \
	    PACKAGESITE=${freebsd_mirror}/pub/FreeBSD/ports/${arch}/packages-${release_downcase}/Latest/ $PKG_ADD -r $package"
    done
}

set_root_password() {
    echo "=> Setting root password, remember to CHANGE IT later" 
    chroot $cf_mount_point sh -c "echo '$root_pass' | /usr/sbin/pw usermod root -H 0"
}

ssh_permit_root_login() {
    if [ ! "`tail -n 1 $cf_mount_point/etc/ssh/sshd_config`" = "PermitRootLogin yes" ]; then
	echo "=> Enabling ssh root login, make sure to disable this later"
	echo "PermitRootLogin yes" >> $cf_mount_point/etc/ssh/sshd_config 
    fi
}

set_time_zone() {
    echo "=> Setting time zone to $time_zone"
    cp $cf_mount_point/usr/share/zoneinfo/$time_zone $cf_mount_point/etc/localtime
    chmod 444 $cf_mount_point/etc/localtime
}

usage() {
    echo
    echo "Usage: `basename $0` -c config_file -d device -m mountpoint -n hostname [-i dhcp_interface]" 
    echo 
    echo "Example: `basename $0` -c etc/alix.conf -d da0 -m /mnt -i vr0 -n ferret.example.org"
    echo
}

# MAIN

# process command line arguments

if [ "$1" = "" ]; then
    usage
    exit 1
fi

while [ "$1" != "" ]; do
    case $1 in
	-c ) shift
             config_file=$1
             ;;
        -d ) shift
	     cf_device=$1 
             ;;
        -m ) shift
	     cf_mount_point=$1 
             ;;
        -n ) shift
	     hostname=$1 
             ;;
        -i ) shift
	     dhcp_if=$1
             ;;
        -h ) usage
	     exit
             ;;
        * ) usage
            exit 1
    esac
    shift
done

# make sure mandatory options are set
if [ "x$dhcp_if" = 'x' ]; then
    dhcp_if=false
fi

if [ "x$config_file" = 'x' ]; then
    echo "ERROR: missing config_file argument"
    usage
    exit 1
fi 

if [ "x$cf_device" = 'x' ]; then
    echo "ERROR: missing device argument"
    usage
    exit 1
fi 

if [ "x$cf_mount_point" = 'x' ]; then
    echo "ERROR: missing mount_point argument"
    usage
    exit 1
fi 

if [ "x$hostname" = 'x' ]; then
    echo "ERROR: missing hostname argument"
    usage
    exit 1
fi 


# source the config file
if [ -f $config_file ]; then
    . $config_file
else
    echo "ERROR: Config file not found in $config_file"
    exit 3
fi


working_dir=`pwd`
release_path="$dist/pub/FreeBSD/releases/$arch/$release" 
custom_kernel=${custom_kernel:-'false'} 

FETCH='/usr/bin/fetch'
GPART='/sbin/gpart'
NEWFS='/sbin/newfs'
MOUNT='/sbin/mount'
PKG_ADD='/usr/sbin/pkg_add'

if [ ! -d  $config_dir ]; then
    echo "ERROR: $config_dir not a directory. quitting"
    exit 3
else
    # get absolute path
    config_dir="`cd $config_dir && pwd`"
fi



echo "=> Running..."

# check if running as root
root_check
echo
echo "Mirror:		$freebsd_mirror"
echo "Release:  	$release"
echo "Architecture:	$arch"
echo "Distributions: 	$distributions"
echo "Custom kernel: 	$custom_kernel"
echo "CF device: 	$cf_device"
echo "Initial config:	$config_dir"
echo "DHCP interface:	$dhcp_if"
echo "Hostname: 	$hostname"
echo 

# ask for confirmation
echo "WARNING: You are about to format and install to /dev/$cf_device"
printf "Are you sure? [y/N]: "
read reply
if [ "$reply" != "y" ];then
    echo "bye"
    exit 1
fi

# check if we have the release files, offer to fetch if not
if [ ! -d $release_path ]; then
    echo "=> $release_path not found" 
    printf "Fetch it from $freebsd_mirror ? [y/N]: "
    read reply2
    fetch_release

    if [ "$reply2" != "y" ];then
	echo "bye"
	exit 1
    fi
fi

# fetch custom kernel if set
if [ $custom_kernel != 'false' ]; then
    fetch_custom_kernel
fi

# Partition the CF card and mount under $cf_mount_point
partition_and_mount

# Install FreeBSD distribution sets
echo "=> Installing FreeBSD distribution sets"
for distribution in $distributions; do
    install_dist $distribution
done

# Install custom kernel if specified
if [ $custom_kernel != 'false' ]; then
   install_custom_kernel
fi 

install_packages

## Configure

install_config
set_hostname
set_dhcp_if
prep_var_for_tmpfs
set_root_password
ssh_permit_root_login
set_time_zone

install_bootcode
echo "=> Unmounting $cf_mount_point"
umount $cf_mount_point
echo "=> Finished"

echo
echo "$dist can be removed if no longer needed"
