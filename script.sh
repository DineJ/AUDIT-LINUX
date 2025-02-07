#!/bin/bash

# Récupère le nom de l'utilisateur courant
use=$(whoami)

# Nom du dossier de travail
work="ynov$RANDOM"

# On s'assure d'être root
if [ "$use" != "root" ]
then
      echo "Vous devez être root !"
      exit -1
fi

# Vérification de l'existance du dossier de travail
if [ -d $work ]
then
	# Suppression pour repartir sur une installation propre
    rm -rf $work
fi

# Vérification de l'OS
release=$(. /etc/os-release && echo $ID_LIKE | grep -F debian)
STATUS="$?"
if [ "$STATUS" -ne 0 ]
then
        echo "Votre système n'est pas un DEBIAN, l'installation ne peut pas continuer"
        exit -1
fi

# Vérification de la présence du paquet "debootstrap" !!!!!!!!!!
# Ce paquet permet l'installation du chroot
grep -A1 -e "Package: debootstrap" /var/lib/dpkg/status | grep -Fq 'Status: install' # Spécifique à DEBIAN !!!!!!!!!!
STATUS="$?"
if [ "$STATUS" -ne 0 ] 
then
	apt update # Spécifique à DEBIAN !!!!!!!!!!
	apt install debootstrap # Spécifique à DEBIAN !!!!!!!!!!
fi

# Création du chroot Bookworm, pour avoir la même distribution que la base choisie
debootstrap bookworm $work

# Création d'un script pour créer le live-build
echo '#!/bin/bash' > $work/create-minimalist.sh
echo '' >> $work/create-minimalist.sh
echo 'apt update' >> $work/create-minimalist.sh
echo 'apt install live-build' >> $work/create-minimalist.sh
echo 'mkdir live' >> $work/create-minimalist.sh
echo 'cd live' >> $work/create-minimalist.sh
echo 'lb config --debian-installer "live"' >> $work/create-minimalist.sh

# Ajout des paquets choisis pour la distribution minimaliste
echo 'cat > config/package-lists/my.list.chroot << EOF' >> $work/create-minimalist.sh
echo 'lxde-core' >> $work/create-minimalist.sh
echo 'firefox-esr-l10n-fr' >> $work/create-minimalist.sh
echo 'abiword' >> $work/create-minimalist.sh
echo 'network-manager' >> $work/create-minimalist.sh
echo 'network-manager-gnome' >> $work/create-minimalist.sh
echo 'EOF' >> $work/create-minimalist.sh

# Création d'un hook post-installation pour installer les pilotes wifi
echo 'cat > config/hooks/live/9999-install-firware-iwlwifi.hook.chroot << EOF' >> $work/create-minimalist.sh
echo '#!/bin/sh' >> $work/create-minimalist.sh
echo '' >> $work/create-minimalist.sh
echo 'set -e' >> $work/create-minimalist.sh
echo '' >> $work/create-minimalist.sh
echo 'echo "deb http://ftp.de.debian.org/debian bookworm main non-free-firmware" > /etc/apt/sources.list.d/iwlwifi.list' >> $work/create-minimalist.sh
echo 'apt update' >> $work/create-minimalist.sh
echo 'apt install firmware-iwlwifi' >> $work/create-minimalist.sh
echo 'apt clean' >> $work/create-minimalist.sh
echo 'EOF' >> $work/create-minimalist.sh

# Déplace le fichier au cas où on voudrait INSTALLER la distribution
echo 'cp -f config/hooks/live/9999-install-firware-iwlwifi.hook.chroot config/hooks/normal/9999-install-firware-iwlwifi.hook.chroot' >> $work/create-minimalist.sh

# Change la version de la distribution pour être sur la stable (Bookworm) et non pas sur la old-stable (bullseye) ou la old-old-stable (wheezy)
echo 'sed -i "s/bullseye/bookworm/g" config/binary config/bootstrap' >> $work/create-minimalist.sh
echo 'sed -i "s/wheezy/bookworm/g" config/binary config/bootstrap' >> $work/create-minimalist.sh

# Modification de la langue systeme, clavier passe de QWERTY à AZERTY et le système sera en français
echo 'sed -i "s/boot=live components/boot=live locales=fr_FR.UTF-8 keyboard-layouts=fr components/g" config/binary' >> $work/create-minimalist.sh

# Création de l'iso
echo 'lb build' >> $work/create-minimalist.sh

# Donne les droits au root d'exécuter, lire et écrire tandis que le groupe et l'utilisateur n'ont le droit que de lire et et exécuter le script
chmod 0755 $work/create-minimalist.sh

# Changement d'OS
systemd-nspawn -D $work /create-minimalist.sh
