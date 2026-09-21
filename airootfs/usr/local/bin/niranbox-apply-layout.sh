#!/usr/bin/env bash
# Se corre una sola vez, automaticamente, al primer login del Modo
# Escritorio (ver /etc/xdg/autostart/niranbox-macos-layout.desktop):
# le pide a Plasma que arme el layout tipo macOS (barra arriba + dock).
set -u

MARKER="${HOME}/.config/niranbox/.layout-applied"
[ -f "${MARKER}" ] && exit 0
mkdir -p "$(dirname "${MARKER}")"

# Le da tiempo a plasmashell de terminar de iniciar antes de mandarle el
# script (plasmashell --script habla con la instancia ya corriendo).
sleep 4

if command -v plasmashell >/dev/null 2>&1; then
    plasmashell --script /usr/share/niranbox/macos-layout.js 2>/dev/null || true
fi

touch "${MARKER}"
