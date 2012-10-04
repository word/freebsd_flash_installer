FreeBSD flash installer
=======================

Automates the process of installing FreeBSD to flash media (memsticks, CF cards, Alix, Soekris)

Features
========

 * Will fetch required FreeBSD release files automatically
 * Can install a custom (pre-compiled) kernel (handy for embedded devices)
 * Can fetch a custom kernel from the network (FTP or HTTP)
 * Can install packages (via pkg_add -r)
 * Uses GPT partitions
   * Currently it will only create a singe root and freebsd-boot partitions
 * Uses TMPFS for /var and /tmp, but persists:
   * /var/db/pkg
   * /var/cron
   * /var/named/etc
 * Can install arbitrary configuration files

Supported releases
==================

9.0-RELEASE up.  Anything older won't work.


Quick start
===========

Perquisites:
 * A box running FreeBSD (9.0 or higher, but it _should_ work on 8.x too)
 * git installed
 * USB stick or CF/SD card with a reader that's supported under FreeBSD

Clone the installer to your FreeBSD machine:

```
git clone https://github.com/word/freebsd_flash_installer.git
```

In freebsd_flash_installer/etc/ you'll find a couple of example configuration files.  One for a generic FreeBSD installation with a few packages and one for an alix firewall.  You can use those examples and craft your own config that suits your needs, but for now we'll use the generic config (generic.conf).

Plug in your flash card/USB stick, run _dmesg_ and note down the device name (e.g. da0)

Run the installer as root.  For example:

```
% sudo freebsd_flash_installer/bin/install.sh -c freebsd_flash_installer/etc/generic.conf -d da0 -m /mnt -n ferret.example.org
```

