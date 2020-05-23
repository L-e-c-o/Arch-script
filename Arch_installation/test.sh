 #!/usr/bin/bash

#BEGIN HELPER FUNCTIONS
RED="\u001b[31m"
GREEN="\u001b[32m"
BLUE="\u001b[34m"
YELLOW="\u001b[33m"
RESET="\u001b[0m"

intro() {
    echo -e "[ $(date +"%T") ][$BLUE EHLO $RESET] $@"
}
stdout() {
    echo -e "[ $(date +"%T") ][$GREEN INFO $RESET] $@"
}
stderr() {
    echo -e "[ $(date +"%T") ][$RED FAIL $RESET] $@ :(" 1>&2
    exit
}
#END HELPER FUNCTIONS

#BEGIN CORE FUNCTIONS
earlyChecks() {
    #test for correct Arch Linux
    if [ ! -e "/etc/arch-release" ]; then
        stderr "Not on Arch Linux, exiting"
    fi

    #test for UEFI
    export INS_IS_EFI=0
    if [ "$(ls /sys/firmware/efi/efivars 2> /dev/null | wc -l)" -gt "0" ]; then
        stdout "This system is UEFI capable"
        export INS_IS_EFI=1
    fi

    #test for network
    if [ ! "$(ping -qc1 1.1.1.1)" ]; then
        stderr "No internet access, exiting"
    fi
    stdout "All checks passed, beginning install"
}

prepare() {
    timedatectl set-ntp true
    stdout "NTP enabled"

    #prompt for disk
    DISKS=$(lsblk -Sne7,11 -oNAME,SIZE)
    if [ "$(echo "$DISKS" | wc -l)" -eq 1 ]; then
        stdout "Only one drive was found, using it"
        export INS_DISK_NAME="/dev/$(echo "$DISKS" | cut -d' ' -f1)"
    else
        stdout "List of available drives :"
        echo "$DISKS" | while read l; do stdout $l; done
        DISK=''
        while [ -z $DISK ] || [ ! -e $INS_DISK_NAME ]; do
            read -p "Enter the desired drive name : " DISK < /dev/tty
            export INS_DISK_NAME="/dev/$DISK"
        done
    fi
    stdout "Install drive is $INS_DISK_NAME"

    #check for minimal size based on self measured requirements
    #this script produces at best a ~1.6GB install with a 256MB boot partition
    if [ "$(lsblk -bnoSIZE -d $INS_DISK_NAME)" -lt "2000000000" ]; then
        stderr "Selected drive is too small. Arch Linux requires a minimum of 2GB, exiting"
    fi
}

formatDisk() {
    #stop script on command error
    set -e

    #wipe drive
    wipefs -a "$INS_DISK_NAME"
    partprobe "$INS_DISK_NAME"
    stdout "Disk has been wiped."

    #create new GPT partition table
    echo "label: gpt" | sfdisk -q "$INS_DISK_NAME"
    partprobe "$INS_DISK_NAME"
    stdout "New GPT partiion table created"

    #create UEFI boot partition and format it
    if [ "$INS_IS_EFI" -eq "1" ]; then
        echo ", 260M, U" | sfdisk -qa "$INS_DISK_NAME"
        partprobe "$INS_DISK_NAME"
        stdout "UEFI boot partition created. Formatting..."

        mkfs.fat -F32 "${INS_DISK_NAME}1"
        partprobe "$INS_DISK_NAME"
        stdout "Boot partition formatting done."
    #otherwise create GRUB BIOS partition
    else
        echo ", 1MiB, 21686148-6449-6E6F-744E-656564454649" | sfdisk -qa "$INS_DISK_NAME"
        partprobe "$INS_DISK_NAME"
        stdout "GRUB BIOS partition created."
    fi

    #create rest of disk Linux partition
    echo ", , L" | sfdisk -qa "$INS_DISK_NAME"
    partprobe "$INS_DISK_NAME"
    stdout "All partitions created. Time to format..."

    mkfs.ext4 -F "${INS_DISK_NAME}2"
    partprobe "$INS_DISK_NAME"

    stdout "Formatting done!"

    #remove flag
    set +e
}

updateMirrors() {
    stdout "Fetching new mirrorlist..."
    curl -sL "https://www.archlinux.org/mirrorlist/?country=FR&country=GB&protocol=https&ip_version=4&ip_version=6&use_mirror_status=on" -o /etc/pacman.d/mirrorlist
    sed -i 's/^#Server/Server/' /etc/pacman.d/mirrorlist
    stdout "New mirrorlist installed. Time to kick ass!"
}

install() {
    stdout "Mounting devices for install..."

    mount "${INS_DISK_NAME}2" /mnt
    if [ "$INS_IS_EFI" -eq "1" ]; then
        mkdir -p /mnt/efi
        mount "${INS_DISK_NAME}1" /mnt/efi
    fi

    PKGLIST="base linux linux-firmware dhcpcd grub iptables openssh"

    #install Intel microcode on compatible computers
    if [ "$(grep -m1 'vendor_id' /proc/cpuinfo | cut -d' ' -f2 )" == "GenuineIntel" ]; then
        PKGLIST="$PKGLIST intel-ucode"
    fi

    #installed required EFI tool when needed
    if [ "$INS_IS_EFI" -eq "1" ]; then
        PKGLIST="$PKGLIST efibootmgr"
    fi

    stdout "Bootstrap time!"
    pacstrap /mnt $PKGLIST

    genfstab -U /mnt >> /mnt/etc/fstab
    stdout "Done! /etc/fstab generated."
    stdout "Preparing the ground for Stage 2..."

    #set up correct locales
    sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /mnt/etc/locale.gen
    sed -i 's/^#fr_FR.UTF-8 UTF-8/fr_FR.UTF-8 UTF-8/' /mnt/etc/locale.gen
    echo "LANG=fr_FR.UTF-8" > /mnt/etc/locale.conf
    echo "KEYMAP=fr" > /mnt/etc/vconsole.conf

    cp "$(realpath $0)" /mnt/stage2.sh
    stdout "Handing control to Stage 2!"
    arch-chroot /mnt ./stage2.sh $INS_IS_EFI $INS_DISK_NAME
}

#this is the actual installation run
run() {
    clear
    loadkeys fr
    intro "Welcome to the Automated Arch Linux installer!"
    intro "By Sean MATTHEWS & Hugo COURTIAL (c) 2020"
    if earlyChecks; then
        prepare
        formatDisk
        updateMirrors
        install
    fi
}

#this is what's run inside the finished chroot
#passed arguments : IS_EFI, DISK_NAME
stage2() {
    intro "Now running Stage 2!"

    stdout "Setting up timezone & locale..."
    ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
    hwclock --systohc
    locale-gen

    #set hostname based on user input
    HOST=''
    while [ -z $HOST ]; do
        read -p "Enter the desired host name : " HOST < /dev/tty
    done
    echo "$HOST" > /etc/hostname
    echo -e "127.0.0.1  localhost\n::1     localhost\n127.0.1.1   $HOST.localdomain  $HOST" >> /etc/hosts

    #set up GRUB
    stdout "Installing GRUB..."
    if [ "$1" -eq "1" ]; then
        grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id="Arch Linux"
    else
        grub-install --target=i386-pc $2
    fi

    stdout "GRUB's here! Generating configuration..."
    grub-mkconfig -o /boot/grub/grub.cfg

    #create user
    USER=''
    while [ -z $USER ]; do
        read -p "Enter the new user name : " USER < /dev/tty
    done
    useradd -m $USER
    stdout "Enter new user password : "
    passwd $USER 

    #set root password
    stdout "Enter root password : "
    passwd 
    rm "$(realpath $0)"

    #enable iptables
    systemctl enable iptables
    #enable ssh
    systemctl enable sshd
    systemctl start sshd
    # RULES HERE
    iptables -A INPUT -p tcp --dport ssh -m conntrack --ctstate NEW -m recent --set 
    iptables -A INPUT -p tcp --dport ssh -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount 2 -j DROP
    iptables -t filter -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -t filter -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -t filter -A INPUT -p tcp --dport 22 -j ACCEPT
    iptables -t filter -A OUTPUT -p udp --dport 53 -j ACCEPT
    iptables -t filter -A OUTPUT -p tcp --dport 80 -j ACCEPT
    iptables -t filter -A OUTPUT -p tcp --dport 443 -j ACCEPT
    iptables -A INPUT -j DROP
    iptables -A OUTPUT -j DROP

    iptables-save -f /etc/iptables/iptables.rules

    stdout "DONE! Exiting Stage 2. Feel free to reboot afterwards :D"
}
#END CORE FUNCTIONS

#script startup, based on its own name
export INS_SELF="$(basename $0)"
case $INS_SELF in
    stage2.sh)
        stage2 $@
        ;;
    sh|bash)
        stderr "Please run the script as its own file"
        ;;
    *)
        run
esac
