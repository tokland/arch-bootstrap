arch-bootstrap
==============

Bootstrap a base Arch Linux system from any GNU distro.

Install
=======

    # install -m 755 arch-bootstrap.sh /usr/local/bin/arch-bootstrap

Examples
=========

Create a base arch distribution in directory 'myarch' (currently running arch by default):

    # arch-bootstrap myarch
   
The same but use arch x86_64 and a given repository source:

    # arch-bootstrap -a x86_64 -r "ftp://ftp.archlinux.org" myarch 

Usage
=====

Once the process has finished, chroot to the destination directory (default user: root/root):

    # chroot destination

Note that some packages require some system directories to be mounted. Some of the commands you can try:

    # mount --bind /proc myarch/proc
    # mount --bind /sys myarch/sys
    # mount --bind /dev myarch/dev
    # mount --bind /dev/pts myarch/dev/pts
    
License
=======

This project is licensed under the terms of the MIT license
