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
RECOVERY_PART="${DISK}2"
ROOT_PART="${DISK}3"
if [[ "${DISK}" == *"nvme"* ]]; then
    EFI_PART="${DISK}p1"
    RECOVERY_PART="${DISK}p2"
    ROOT_PART="${DISK}p3"
fi

# La particion RECOVERY guarda una copia del propio medio de instalacion
# (el mismo squashfs+kernel del USB), para poder reinstalar de fabrica
# desde el menu de arranque sin necesitar el USB otra vez.
echo "==> Particionando ${DISK} (GPT: 1GiB EFI + 4GiB recuperacion + resto root)"
sgdisk --zap-all "${DISK}"
sgdisk -n1:0:+1GiB   -t1:ef00 -c1:EFI "${DISK}"
sgdisk -n2:0:+4GiB   -t2:8300 -c2:RECOVERY "${DISK}"
sgdisk -n3:0:0       -t3:8300 -c3:ROOT "${DISK}"
partprobe "${DISK}"

echo "==> Formateando"
mkfs.fat -F32 -n EFI "${EFI_PART}"
mkfs.ext4 -F -L RECOVERY "${RECOVERY_PART}"
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
install -Dm755 "${SRC}usr/local/bin/niranbox-session-launcher.sh" \
               /mnt/usr/local/bin/niranbox-session-launcher.sh
install -Dm755 "${SRC}usr/local/bin/steamos-session-select" \
               /mnt/usr/local/bin/steamos-session-select
install -Dm644 "${SRC}usr/share/wayland-sessions/gamescope-session.desktop" \
               /mnt/usr/share/wayland-sessions/gamescope-session.desktop
install -Dm644 "${SRC}usr/share/applications/niranbox-volver-a-juego.desktop" \
               /mnt/usr/share/applications/niranbox-volver-a-juego.desktop
install -Dm644 "${SRC}usr/share/pixmaps/niranbox-logo.png" \
               /mnt/usr/share/pixmaps/niranbox-logo.png
install -Dm644 "${SRC}usr/share/pixmaps/niranbox-logo-small.png" \
               /mnt/usr/share/pixmaps/niranbox-logo-small.png
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
timeout 10
console-mode max
EOF
ROOT_UUID="$(findmnt -no UUID /)"
cat > /boot/loader/entries/niranbox.conf <<EOF
title   NiranBox
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=UUID=${ROOT_UUID} rw quiet splash
EOF

mkdir -p /usr/share/applications
cat > /usr/share/applications/niranbox-restaurar.desktop <<'EOF'
[Desktop Entry]
Name=Restaurar NiranBox de fabrica
Comment=Reinicia y abre el instalador para reinstalar NiranBox desde cero
Exec=systemctl reboot --boot-loader-entry=recovery
Icon=/usr/share/pixmaps/niranbox-logo.png
Type=Application
Terminal=false
Categories=System;
EOF
CHROOT_EOF

INSTALL_DIR_NAME="${DISTRO_NAME,,}"
LIVE_BOOTMNT="/run/archiso/bootmnt"
if [ -d "${LIVE_BOOTMNT}/${INSTALL_DIR_NAME}/x86_64" ]; then
    echo "==> Preparando particion de recuperacion (copia de fabrica)"
    mkdir -p /mnt-recovery
    mount "${RECOVERY_PART}" /mnt-recovery
    mkdir -p "/mnt-recovery/${INSTALL_DIR_NAME}/x86_64"
    cp -a "${LIVE_BOOTMNT}/${INSTALL_DIR_NAME}/x86_64/airootfs.sfs" \
          "/mnt-recovery/${INSTALL_DIR_NAME}/x86_64/airootfs.sfs"
    cp -a "${LIVE_BOOTMNT}/${INSTALL_DIR_NAME}/boot/x86_64/vmlinuz-linux" /mnt/boot/vmlinuz-recovery
    cp -a "${LIVE_BOOTMNT}/${INSTALL_DIR_NAME}/boot/x86_64/initramfs-linux.img" /mnt/boot/initramfs-recovery.img
    umount /mnt-recovery
    rmdir /mnt-recovery
    RECOVERY_UUID="$(blkid -s UUID -o value "${RECOVERY_PART}")"
    # copytoram=y es obligatorio aqui (a diferencia del USB): la recuperacion
    # reinstala sobre EL MISMO disco del que arranco. Sin copiar el squashfs
    # entero a RAM primero, sgdisk --zap-all destruiria la particion RECOVERY
    # mientras el sistema live la sigue usando para arrancar -> crash. Un
    # mini PC de gama gamer siempre trae RAM de sobra (8GB+) para esto.
    cat > /mnt/boot/loader/entries/recovery.conf <<EOF
title   Restaurar NiranBox (borra todo y reinstala de fabrica)
linux   /vmlinuz-recovery
initrd  /initramfs-recovery.img
options archisobasedir=${INSTALL_DIR_NAME} archisosearchuuid=${RECOVERY_UUID} copytoram=y
EOF
    echo "==> Particion de recuperacion lista."
else
    echo "AVISO: no se encontro el medio de arranque en ${LIVE_BOOTMNT}." >&2
    echo "       (normal si no arrancaste desde el USB de NiranBox). La" >&2
    echo "       particion de recuperacion quedo vacia, sin entrada de" >&2
    echo "       arranque -- para restaurar de fabrica habria que usar el USB." >&2
fi

echo "==> Listo. Desmontando."
umount -R /mnt
echo "Instalacion terminada. Puedes reiniciar y quitar el USB."
echo "Arranca directo a Steam. Para el Modo Escritorio (KDE Plasma):"
echo "  steamos-session-select plasma"
