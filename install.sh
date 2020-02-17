#!/bin/bash

# verification de la connexion
test=$(ping -c 3  1.1.1.1 | awk -F " " {'print $6'})
if [[ $test == *ttl* ]]
then
	echo "connexion etablie"
else
	echo "Veuilliez disposer d'une connexion internet valide."
	exit
fi	
# mise a jour de l'horloge
timedatectl set-ntp true
# recuperation du nom de disque
disk=$(fdisk -l | sed -n '1p' | awk -F " " {'print $2'} | sed  's/://')	
# verification de l'espace disque min 2.5 gB
space=$(fdisk -l | sed -n '1p' | awk -F " " {'print $5 / 1048576'})
if [ $space -lt 2500 ]
then
	echo "espace disque insuffisant."
	exit
fi
# partionnement  
ram=$( free --si --mega | grep Mem | awk -F " " {'print $2'})
if [ $ram -lt 8000 ]
then
	swap=$ram
elif [ $ram -ge 8000 && $ram -lt 16000]
then
	$swap=$(( $ram / 2))
elif [ $ram -ge 16000 ]
then
	$swap=0
fi
# verif taille apres swap
if [ $((space-swap)) -lt 2500 ]
then
	echo " espace insuffisant ."
	exit
fi
# RAZ du disque
wipefs -a $disk
partprobe $disk

# var partition
swap_fin=$(( $boot + $swap +1 ))
root=$((space-(swap+boot)))

# verifier le type de bios 
if [ -e "/sys/firmware/efi/efivars" ]
then
	efi=true
	boot=512
	echo "UEFI detecté"
	parted --script "${disk}" -- mklabel gpt \
  	mkpart ESP fat32 1 ${boot} \
  	set 1 esp on \
  	mkpart primary linux-swap ${boot} ${swap_fin} \
  	mkpart primary ext4 ${swap_fin} 100%
	mkfs.fat -F32  ${disk}1
else
	efi=false
	boot=3
	echo "LEGACY detecté"
	parted --script "${disk}" -- mklabel gpt \
  	mkpart legacy_boot fat32 1 ${boot} \
  	set 1 bios_grub on \
  	mkpart primary linux-swap ${boot} ${swap_fin} \
  	mkpart primary ext4 ${swap_fin} 100%
fi
# formatage des partitions
mkswap ${disk}2
swapon ${disk}2
mkfs.ext4 ${disk}3
partprobe $disk

# montage des partitions
mount ${disk}3 /mnt
if [ efi == true ]
then
	mkdir -p /mnt/efi
	mount ${disk}1 /mnt/efi
	# bootstraping
	pacstrap /mnt base linux linux-firmware grub dhcpcd efibootmg
else
	# bootstraping
	pacstrap /mnt base linux linux-firmware grub dhcpcd	
fi

# generation du fichier fstab
genfstab -U /mnt >> /mnt/etc/fstab

# script de config
config="ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime\n
hwclock --systohc\n
echo fr_FR.UTF-8 UTF-8 >> /etc/locale.gen\n
echo LANG=fr_FR.UTF-8 >> /etc/locale.conf\n
export LANG=fr_FR.UTF-8\n
locale-gen\n
echo KEYMAP=fr >> /etc/vconsole.conf\n
echo Linux4life >> /etc/hostname\n
echo \"127.0.0.1		localhost\" >> /etc/hosts\n
echo \"::1			localhost\" >> /etc/hosts\n
echo \"127.0.1.1		Linux4life.localdomain	Linux4life\" >> /etc/hosts\n
echo ' Entrez un mot de passe de root :'\n
read mdp \n
echo -e \"\$mdp\\n\$mdp\" | (passwd root)\n
if [ ${efi}==false ]\n
then\n
grub-install --target=i386-pc \"${disk}\"\n
else\n
grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=\"Arch Linux\"\n
fi\n
grub-mkconfig -o /boot/grub/grub.cfg\n
exit\n"	

# chroot + script
echo -e $config > /mnt/config.sh
chmod +x /mnt/config.sh
arch-chroot /mnt ./config.sh
