FreeBSD flash installer
=======================

Automates the process of installing FreeBSD to flash media (memsticks, CF cards, Alix, Soekris)

Features
========

 * Will fetch required FreeBSD release files automatically (only if not present already)
 * Can install a custom (pre-compiled) kernel (handy for embedded devices)
 * Can fetch a custom kernel from the network (FTP or HTTP)
 * Can install packages (via pkg_add -r)
 * Uses GPT partitions
   * Currently it will only create a singe root and freebsd-boot partition
 * File systems mounted with 'noatime' by default to save disk writes and extend 
   the life of flash media
 * Uses GEOM labels in fstab, which means the system will boot as usual even
   when the disk device name changes (e.g. the flash media is moved to a
   different port/computer)
 * Uses TMPFS for /var and /tmp, but persists:
   * /var/db/pkg
   * /var/cron
   * /var/named/etc
 * Can install arbitrary configuration files
 * Can configure a network interface to obtain network configuration via DHCP 
 * Alix specific features:
   * Serial console enabled
   * Tuned kernel:
     * Stripped down things not relevant to Alix
     * AMD Geode crypto acceleration enabled (handy for VPNs)
     * Enabled DEVICE_POLLING - high network load generates less CPU load
     * Front LED driver (sample usage script included)

Supported releases
==================

9.0-RELEASE up.  Anything older won't work.


Quick start
===========

Perquisites:
 * A box running FreeBSD (9.0 or higher, but it _should_ work on 8.x too)
 * git installed
 * USB stick or CF/SD card with a reader that's supported under FreeBSD

Clone the installer on your FreeBSD box:

```
git clone https://github.com/word/freebsd_flash_installer.git
```

In freebsd_flash_installer/etc/ you'll find a couple of example configuration
files.  One for a generic FreeBSD installation with a few additional packages
and one for an alix firewall.  You can use these examples and craft your own
config that suits your needs, but for for the sake of this simple example we'll
use the generic config (generic.conf).

Plug in your flash card/USB stick, run _dmesg_ and note down the device name
(e.g. da0)

Run the installer as root.  For example:

```
% sudo freebsd_flash_installer/bin/install.sh -c freebsd_flash_installer/etc/generic.conf -d da0 -m /mnt -n ferret.example.org
```

If you get the following error message:

```
Error: /dev/da0 already contains a partition table.
```

It means that your usb stick already contains a partition table.  You can clear
it with the destroy_geom.sh script provided:

```
sudo ./freebsd_flash_installer/bin/destroy_geom.sh -d da0 
```

Run the installer again to continue with the installation.

More detailed docs are on the wiki:
 * https://github.com/word/freebsd_flash_installer/wiki
