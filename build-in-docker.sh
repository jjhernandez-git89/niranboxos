#!/usr/bin/env bash
# Compila la ISO de NiranBoxOS usando un contenedor de Arch Linux, para poder
# hacerlo desde un host que NO es Arch (ej. una VM Ubuntu/Debian). Necesita
# Docker instalado en el host:
#   sudo apt update && sudo apt install -y docker.io
set -e -u -o pipefail

PROFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v docker >/dev/null 2>&1; then
    echo "Falta Docker. Instalalo con: sudo apt update && sudo apt install -y docker.io" >&2
    exit 1
fi

# --privileged: mkarchiso necesita montar squashfs/loop devices, algo que un
# contenedor normal no puede hacer.
docker run --rm --privileged \
    -v "${PROFILE_DIR}:/repo" \
    -w /repo \
    archlinux:base-devel \
    bash -c '
        set -e
        pacman-key --init
        pacman-key --populate archlinux
        pacman -Syu --noconfirm --needed archiso git
        ./build.sh
    '

echo "Listo. ISO generada en: ${PROFILE_DIR}/out"
