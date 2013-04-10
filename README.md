arch-bootstrap
==============

Bootstrap a base Arch Linux system.

Install
=======

    # install -m 755 arch-bootstrap.sh /usr/local/bin/arch-bootstrap

Examples
=========

Create base Arch Linux in directory 'myarch' (i686 arch by default):

   # arch-bootstrap myarch
   
Use a specific arch and a repository source:

   # arch-bootstrap -a x86_64 -r "ftp://ftp.archlinux.org" myarch 

Usage
=====

Once the process has finished, chroot to the destination directory (default user: root/root):

   # chroot destination

Note that some packages may need system directories mounted:

    # mount --bind /proc myarch/proc
    # mount --bind /sys myarch/sys
    # mount --bind /dev myarch/dev
