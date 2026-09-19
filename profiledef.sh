#!/usr/bin/env bash
# shellcheck disable=SC2034

_profile_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=distro.conf
source "${_profile_dir}/distro.conf"

iso_name="${DISTRO_NAME,,}"                 # minusculas: requerido por mkarchiso
iso_label="${DISTRO_ISO_LABEL}_$(date +%Y%m)"
iso_publisher="${DISTRO_PRETTY_NAME} <https://example.org>"
iso_application="${DISTRO_PRETTY_NAME} Live/Install medium"
iso_version="$(date +%Y.%m.%d)"
# "arch": no es un typo. La convencion que usan casi todas las distros basadas
# en Arch con Calamares (EndeavourOS, ArcoLinux...) es dejar install_dir=arch
# porque el modulo unpackfs de Calamares (ver airootfs/etc/calamares) espera
# encontrar el squashfs en /run/archiso/bootmnt/arch/x86_64/airootfs.sfs.
install_dir="arch"
buildmodes=('iso')
# Solo UEFI (moderno): casi todo el hardware de los ultimos ~10 anos lo trae.
# Se deja fuera el arranque BIOS/syslinux para no tener que mantener tambien
# esa carpeta (syslinux/) por separado.
bootmodes=('uefi.systemd-boot')
arch="x86_64"
pacman_conf="${_profile_dir}/pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/.automated_script.sh"]="0:0:755"
  ["/usr/local/bin/start-gamescope-session.sh"]="0:0:755"
  ["/usr/local/bin/xinitrc-niranbox-installer"]="0:0:755"
  ["/usr/local/bin/niranbox-postinstall.sh"]="0:0:755"
  ["/usr/local/bin/steamos-session-select"]="0:0:755"
  ["/root/customize_airootfs.sh"]="0:0:755"
)
