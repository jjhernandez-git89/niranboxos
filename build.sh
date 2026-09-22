#!/usr/bin/env bash
# Construye la ISO de NiranBoxOS con mkarchiso.
#
# mkarchiso SOLO corre en Linux (usa pacstrap, chroot, mount de squashfs...).
# No funciona en macOS. Ejecuta este script:
#   - dentro de una maquina/VM Linux (Arch o Arch en Docker), o
#   - directamente en el PC de pruebas, arrancado desde el ISO oficial de
#     Arch Linux (ahi ya viene mkarchiso instalado).
set -e -u -o pipefail

PROFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${PROFILE_DIR}/out"

# Root ya (ej. dentro de un contenedor Docker, ver build-in-docker.sh) no
# necesita sudo; en un Arch normal con un usuario si.
SUDO="sudo"
if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
fi

if [ "$(uname -s)" != "Linux" ]; then
    echo "Este script debe correr en Linux (no macOS). Ver comentario arriba." >&2
    exit 1
fi

if ! command -v mkarchiso >/dev/null 2>&1; then
    echo "Falta 'archiso'. Instalalo con: ${SUDO} pacman -S --needed archiso" >&2
    exit 1
fi

if ! command -v pacman-key >/dev/null 2>&1; then
    echo "Falta pacman-key (no parece un sistema Arch)." >&2
    exit 1
fi
if [ ! -d /etc/pacman.d/gnupg ] || [ -z "$(ls -A /etc/pacman.d/gnupg 2>/dev/null)" ]; then
    ${SUDO} pacman-key --init
    ${SUDO} pacman-key --populate archlinux
fi

# El instalador grafico y el manual (dentro del ISO) necesitan su propia
# copia de estos archivos; se sincroniza sola en cada build para no tener
# que acordarse de hacerlo a mano.
mkdir -p "${PROFILE_DIR}/airootfs/opt/niranbox"
cp "${PROFILE_DIR}/distro.conf" "${PROFILE_DIR}/packages.x86_64" \
   "${PROFILE_DIR}/install/install-target.sh" \
   "${PROFILE_DIR}/airootfs/opt/niranbox/"
chmod 755 "${PROFILE_DIR}/airootfs/opt/niranbox/install-target.sh"

mkdir -p "${OUT_DIR}"
${SUDO} mkarchiso -v -o "${OUT_DIR}" "${PROFILE_DIR}"

echo "Listo. ISO generada en: ${OUT_DIR}"
