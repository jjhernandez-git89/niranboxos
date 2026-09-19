#!/usr/bin/env bash
#
# Instalador persistente de NiranBox. Se ejecuta DENTRO de la sesion live
# (arrancada desde el USB), como root, apuntando a un disco real.
#
# ATENCION: esto borra por completo el disco de destino. Por defecto pide
# confirmacion escrita; el instalador grafico (niranbox-installer-gui.sh) ya
# confirma con sus propios dialogos, asi que llama a este script con
# NIRANBOX_ASSUME_YES=1 para saltarse esta confirmacion de terminal.
#
#   sudo ./install-target.sh /dev/nvme0n1 [usuario]
#
# Variables opcionales:
#   NIRANBOX_ASSUME_YES=1     no pide confirmacion por terminal
#   NIRANBOX_PASSWORD=...     password real para el usuario (si no se da,
#                              la cuenta queda sin password, como en modo
#                              consola / Steam Deck)
set -e -u -o pipefail

# Este mismo script vive en dos lugares: install/install-target.sh dentro
# del repo (junto a distro.conf un nivel arriba), y una copia plana en
# /opt/niranbox/install-target.sh dentro del ISO ya construido (junto a
# distro.conf en el mismo directorio). Se detecta solo.
_script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${_script_dir}/distro.conf" ]; then
    PROFILE_DIR="${_script_dir}"
else
    PROFILE_DIR="$(cd "${_script_dir}/.." && pwd)"
fi
# shellcheck source=../distro.conf
source "${PROFILE_DIR}/distro.conf"

DISK="${1:-}"
if [ -z "${DISK}" ] || [ ! -b "${DISK}" ]; then
    echo "Uso: $0 /dev/sdX [usuario]   (debe ser un disco en bloque valido, ej. /dev/nvme0n1)" >&2
    lsblk -d -o NAME,SIZE,MODEL
    exit 1
fi
DISTRO_USER="${2:-${DISTRO_USER}}"

if [ "${NIRANBOX_ASSUME_YES:-0}" != "1" ]; then
    echo "=============================================================="
    echo " Vas a BORRAR POR COMPLETO: ${DISK}"
    lsblk "${DISK}"
    echo "=============================================================="
    read -r -p "Escribe exactamente '${DISK}' para confirmar: " CONFIRM
    if [ "${CONFIRM}" != "${DISK}" ]; then
        echo "No coincide. Cancelado, no se toco nada." >&2
        exit 1
    fi
fi

EFI_PART="${DISK}1"
ROOT_PART="${DISK}2"
if [[ "${DISK}" == *"nvme"* ]]; then
    EFI_PART="${DISK}p1"
    ROOT_PART="${DISK}p2"
fi

echo "==> Particionando ${DISK} (GPT: 512MiB EFI + resto root)"
sgdisk --zap-all "${DISK}"
sgdisk -n1:0:+512MiB -t1:ef00 -c1:EFI "${DISK}"
sgdisk -n2:0:0       -t2:8300 -c2:ROOT "${DISK}"
partprobe "${DISK}"

echo "==> Formateando"
mkfs.fat -F32 -n EFI "${EFI_PART}"
mkfs.ext4 -F -L ROOT "${ROOT_PART}"

echo "==> Montando"
mount "${ROOT_PART}" /mnt
mkdir -p /mnt/boot
mount "${EFI_PART}" /mnt/boot

echo "==> Instalando paquetes base (pacstrap), puede tardar bastante"
mapfile -t PKGS < <(grep -vE '^\s*#|^\s*$' "${PROFILE_DIR}/packages.x86_64")
pacstrap -K /mnt "${PKGS[@]}"

echo "==> Copiando personalizacion (usuario, sesiones, branding)"
# Si estamos arrancados desde nuestra propia ISO live, estos archivos ya
# existen ahi mismo (los trae el propio ISO). Si no (Arch generico + este
# repo clonado a mano), se usa la copia de referencia en airootfs/.
if [ -f /usr/local/bin/start-gamescope-session.sh ]; then
    SRC="/"
else
    SRC="${PROFILE_DIR}/airootfs/"
fi
install -Dm644 "${SRC}etc/os-release" /mnt/etc/os-release
install -Dm755 "${SRC}usr/local/bin/start-gamescope-session.sh" \
               /mnt/usr/local/bin/start-gamescope-session.sh
install -Dm755 "${SRC}usr/local/bin/steamos-session-select" \
               /mnt/usr/local/bin/steamos-session-select
install -Dm644 "${SRC}usr/share/wayland-sessions/gamescope-session.desktop" \
               /mnt/usr/share/wayland-sessions/gamescope-session.desktop
install -Dm644 "${SRC}usr/share/pixmaps/niranbox-logo.png" \
               /mnt/usr/share/pixmaps/niranbox-logo.png
mkdir -p /mnt/usr/share/plymouth/themes/niranbox
cp -a "${SRC}usr/share/plymouth/themes/niranbox/." /mnt/usr/share/plymouth/themes/niranbox/
install -Dm644 "${SRC}etc/systemd/zram-generator.conf" \
               /mnt/etc/systemd/zram-generator.conf

genfstab -U /mnt >> /mnt/etc/fstab

echo "==> Configurando sistema instalado (chroot)"
arch-chroot /mnt /bin/bash -e -s -- "${DISTRO_USER}" "${NIRANBOX_PASSWORD:-}" <<'CHROOT_EOF'
set -e -u
DISTRO_USER="$1"
DISTRO_PASSWORD="$2"

ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "niranbox" > /etc/hostname

useradd -m -G wheel,video,input,render,audio,storage "${DISTRO_USER}"
if [ -n "${DISTRO_PASSWORD}" ]; then
    echo "${DISTRO_USER}:${DISTRO_PASSWORD}" | chpasswd
else
    passwd -d "${DISTRO_USER}"
fi
echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/10-wheel-nopasswd
chmod 440 /etc/sudoers.d/10-wheel-nopasswd

mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/autologin.conf <<EOF
[Autologin]
User=${DISTRO_USER}
Session=gamescope-session.desktop
Relogin=true
EOF

systemctl enable NetworkManager.service
systemctl enable systemd-timesyncd.service
systemctl enable bluetooth.service
systemctl enable sddm.service
systemctl enable cups.service
systemctl enable reflector.service
systemctl --global enable pipewire.service pipewire-pulse.service wireplumber.service

# Splash de arranque: mete el hook 'plymouth' en mkinitcpio (justo despues de
# 'base udev') y activa el tema NiranBox, que regenera el initramfs solo.
sed -i -E 's/^(HOOKS=\([^)]*\b(udev|systemd)\b)/\1 plymouth/' /etc/mkinitcpio.conf
plymouth-set-default-theme -R niranbox

bootctl install
cat > /boot/loader/loader.conf <<'EOF'
default niranbox.conf
timeout 3
console-mode max
EOF
ROOT_UUID="$(findmnt -no UUID /)"
cat > /boot/loader/entries/niranbox.conf <<EOF
title   NiranBox
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=UUID=${ROOT_UUID} rw quiet splash
EOF
CHROOT_EOF

echo "==> Listo. Desmontando."
umount -R /mnt
echo "Instalacion terminada. Puedes reiniciar y quitar el USB."
echo "Arranca directo a Steam. Para el Modo Escritorio (KDE Plasma):"
echo "  steamos-session-select plasma"
