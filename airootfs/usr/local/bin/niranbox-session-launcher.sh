#!/usr/bin/env bash
# Corre DENTRO de gamescope (ver start-gamescope-session.sh). La primera vez
# que el usuario final enciende su mini PC, muestra una bienvenida breve
# (se cierra sola, no depende de que el clic funcione) y despues arranca
# Steam. Las veces siguientes va directo a Steam.
set -u

MARKER="${HOME}/.config/niranbox/.welcomed"
LOGO="/usr/share/pixmaps/niranbox-logo-small.png"

if [ ! -f "${MARKER}" ] && command -v yad >/dev/null 2>&1; then
    mkdir -p "$(dirname "${MARKER}")"
    yad --image="${LOGO}" --width=560 --center --on-top \
        --no-buttons --timeout=12 --timeout-indicator=bottom \
        --text="<b>Bienvenido a NiranBoxOS</b>\n\nEstas en <b>Modo Steam Deck</b>. Steam va a abrir en un momento, en modo Big Picture.\n\nPara ir al <b>Modo Escritorio</b> (archivos, navegador, LibreOffice), abre el menu de Steam (boton con forma de Xbox/Guide en el control, o Menu > Power) y elige <b>Cambiar a escritorio</b>.\n\nPara volver a Modo Steam Deck desde el escritorio, busca el icono 'Volver a Modo Steam Deck'." \
        2>/dev/null
    touch "${MARKER}"
fi

exec steam -tenfoot -pipewire-dmabuf -steamdeck -steamos3
