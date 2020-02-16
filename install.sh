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
space=$(fdisk -l | sed -n '1p' | awk -F " " {'print $5'})
if [ $space -lt 2684354560 ]
then
	echo "espace disque insuffisant."
	exit
fi

# partionnement  
ram=$( sed -n '1p' /proc/meminfo  | awk -F " " {'print $2'}) 
swap=$ram
boot=536870900
root=$(($space-($swap+$boot)))

while [ $root -lt $swap  ]
do
	swap=$(($swap-$boot))
	root=$(($root+$boot))
done

echo " swap = $swap "
echo " root = $root "


# verifier le type de bios ---> ls /sys/firmware/efi/efivars
if [ -f "/sys/firmware/efi/efivars" ]
then
	efi=true
	echo "UEFI detecté"
else
	efi=false
	echo "LEGACY detecté"
fi
#
