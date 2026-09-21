#!/usr/bin/env bash
# Sesion que SDDM arranca por defecto (ver Session=niranbox-chooser.desktop
# en /etc/sddm.conf.d/autologin.conf).
#
# Dos casos:
# 1) Cambio rapido ya estando adentro (steamos-session-select / iconos
#    "Volver a Modo Steam Deck" y "Cambiar a escritorio"): dejan escrito
#    ~/.config/niranbox/.next-session y reinician la sesion. Aqui se lee
#    ese archivo y se pasa DIRECTO a la sesion pedida, sin preguntar nada.
# 2) Arranque real de la PC (encendido): no hay archivo, asi que se
#    pregunta con un tiempo corto. Si no se toca nada, arranca en
#    Modo Escritorio (KDE) por defecto.
set -u

export XDG_RUNTIME_DIR="/run/user/$(id -u)"
mkdir -p "${XDG_RUNTIME_DIR}"

NEXT_FILE="${HOME}/.config/niranbox/.next-session"
if [ -f "${NEXT_FILE}" ]; then
    NEXT="$(cat "${NEXT_FILE}")"
    rm -f "${NEXT_FILE}"
    if [ "${NEXT}" = "gamescope" ]; then
        exec /usr/local/bin/start-gamescope-session.sh
    else
        exec dbus-run-session startplasma-wayland
    fi
fi

# Default = Modo Escritorio (1) si por algun motivo no hay yad para
# preguntar. Se pisa con el codigo real del boton que se apriete.
RC=1
if command -v yad >/dev/null 2>&1; then
    yad --title="NiranBox" --image="/usr/share/pixmaps/niranbox-logo-small.png" \
        --width=560 --center --on-top \
        --text="<b>Como quieres usar NiranBox?</b>\n\nSin elegir nada, arranca en Modo Escritorio." \
        --timeout=8 --timeout-indicator=bottom \
        --button="Modo Escritorio:1" \
        --button="Modo Steam Deck:0" \
        2>/dev/null
    RC=$?
fi

# Solo el boton "Modo Steam Deck" (codigo 0) lleva a gamescope. Cualquier
# otra cosa (timeout, "Modo Escritorio", cerrar la ventana) cae en Modo
# Escritorio, que es el default pedido.
if [ "${RC}" = "0" ]; then
    exec /usr/local/bin/start-gamescope-session.sh
else
    exec dbus-run-session startplasma-wayland
fi
