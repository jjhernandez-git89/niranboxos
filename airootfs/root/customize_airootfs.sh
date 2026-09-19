#!/usr/bin/env bash
# Se ejecuta dentro del chroot durante el build de la ISO (mkarchiso).
# Crea el usuario con el que arranca la sesion de juego y activa servicios.
set -e -u

DISTRO_USER="deck"

useradd -m -G wheel,video,input,render,audio,storage -s /bin/bash "${DISTRO_USER}"
# En la ISO live no pedimos password para poder loguear/instalar rapido.
passwd -d "${DISTRO_USER}"
echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/10-wheel-nopasswd
chmod 440 /etc/sudoers.d/10-wheel-nopasswd

systemctl enable NetworkManager.service
systemctl enable systemd-timesyncd.service
systemctl enable getty@tty1.service
systemctl --global enable pipewire.service pipewire-pulse.service wireplumber.service

# Locale minimo para que arranque sin configurar nada
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

# Deja NiranBox como tema Plymouth por defecto. Nota: el splash visual en el
# propio USB live no esta garantizado (archiso arma su initramfs con su
# propio preset, no con /etc/mkinitcpio.conf). La instalacion persistente en
# disco (install/install-target.sh) si mete el hook 'plymouth' y regenera el
# initramfs correctamente, asi que ahi el splash se ve siempre.
plymouth-set-default-theme niranbox || true
