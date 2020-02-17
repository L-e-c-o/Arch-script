#!/bin/bash

# verification de la connection
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

# recup nom de disque
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

if [ ( $space - $swap ) -lt 2500 ]
then
	echo " espace insuffisant ."
	exit
fi

#while [ $root -lt $swap  ]
#do
#	swap=$(($swap-$boot))
#	root=$(($root+$boot))
#done

# test 1
echo " test 1"
echo " ram = $ram "
echo " swap = $swap "
echo " boot = $boot "

# RAZ du disque
wipefs -a $disk
partprobe $disk

# var part
swap_fin=$(( $boot + $swap +1 ))
root=$(($space-($swap+$boot)))

# test 2
echo " test 2 "
echo " swap_fin = $swap_fin "
echo " boot = $boot "

# verifier le type de bios ---> ls /sys/firmware/efi/efivars
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
else
	efi=false
	boot=2
	echo "LEGACY detecté"
	parted --script "${disk}" -- mklabel gpt \
  	mkpart legacy_boot fat32 1 ${boot} \
  	set 1 bios_grub on \
  	mkpart primary linux-swap ${boot} ${swap_fin} \
  	mkpart primary ext4 ${swap_fin} 100%

fi
#check bolean

# test
fdisk -l
