#!/usr/bin/env bash
# Construye la ISO de NiranBox con mkarchiso.
#
# mkarchiso SOLO corre en Linux (usa pacstrap, chroot, mount de squashfs...).
# No funciona en macOS. Ejecuta este script:
#   - dentro de una maquina/VM Linux (Arch o Arch en Docker), o
#   - directamente en el PC de pruebas, arrancado desde el ISO oficial de
#     Arch Linux (ahi ya viene mkarchiso instalado).
set -e -u -o pipefail

PROFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${PROFILE_DIR}/out"

if [ "$(uname -s)" != "Linux" ]; then
    echo "Este script debe correr en Linux (no macOS). Ver comentario arriba." >&2
    exit 1
fi

if ! command -v mkarchiso >/dev/null 2>&1; then
    echo "Falta 'archiso'. Instalalo con: sudo pacman -S --needed archiso" >&2
    exit 1
fi

# El instalador grafico (calamares) no esta en los repos oficiales de Arch,
# solo en Chaotic-AUR (repo binario de terceros). Sin este paso, mkarchiso no
# podria resolver/firmar ese paquete y el build fallaria.
if ! pacman-key --list-keys 3056513887B78AEB >/dev/null 2>&1; then
    echo "==> Dando de alta la llave de Chaotic-AUR (necesaria para 'calamares')"
    sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
    sudo pacman-key --lsign-key 3056513887B78AEB
fi
if ! pacman -Q chaotic-keyring >/dev/null 2>&1; then
    sudo pacman -U --noconfirm \
        'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' \
        'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
fi
if ! grep -q '^\[chaotic-aur\]' /etc/pacman.conf; then
    echo "AVISO: tu /etc/pacman.conf (del host de build) no tiene [chaotic-aur]." >&2
    echo "Anadelo (ver pacman.conf de este perfil) y vuelve a correr build.sh." >&2
    exit 1
fi

mkdir -p "${OUT_DIR}"
sudo mkarchiso -v -o "${OUT_DIR}" "${PROFILE_DIR}"

echo "Listo. ISO generada en: ${OUT_DIR}"
