#!/usr/bin/env bash
# Instalador grafico de NiranBox (yad). Corre como root, dentro de la sesion
# X del USB live (ver xinitrc-niranbox-installer). Es un wrapper visual sobre
# install/install-target.sh: junta disco/usuario/password con dialogos y
# corre la instalacion real con una barra de progreso.
set -u

INSTALL_SCRIPT="/opt/niranbox/install-target.sh"
# La version chica (160x160): yad no re-escala --image, y el pixmap grande
# (1047x1047) hacia que la ventana ocupara toda la pantalla y los botones
# quedaran fuera de la vista.
LOGO="/usr/share/pixmaps/niranbox-logo-small.png"
YAD_TITLE="Instalar NiranBox"

yad_ok() { command -v yad >/dev/null 2>&1; }
if ! yad_ok; then
    echo "Falta 'yad'." >&2
    exit 1
fi

# 1) Bienvenida
yad --title="${YAD_TITLE}" --image="${LOGO}" --width=520 --center \
    --text="<b>Bienvenido a NiranBox</b>\n\nEste asistente va a instalar NiranBox en el disco que elijas.\n\n<b>Esto borra todo el contenido de ese disco.</b> Asegurate de elegir el correcto." \
    --button="Cancelar:1" --button="Continuar:0"
[ "$?" -eq 0 ] || exit 0

# 2) Elegir disco
mapfile -t DISK_ROWS < <(lsblk -d -n -o NAME,SIZE,MODEL -e 7,11 | \
    awk '{printf "/dev/%s\n%s (%s)\n", $1, $2, substr($0, index($0,$3))}')
if [ "${#DISK_ROWS[@]}" -eq 0 ]; then
    yad --title="${YAD_TITLE}" --text="No encuentro ningun disco." --button="Cerrar:0"
    exit 1
fi
DISK="$(yad --title="${YAD_TITLE}" --width=520 --height=320 --center \
    --list --separator="" --print-column=1 \
    --text="Elige el disco donde instalar NiranBox:" \
    --column="Disco" --column="Detalle" \
    "${DISK_ROWS[@]}")"
[ -n "${DISK}" ] || exit 0

# 3) Confirmacion escrita (a proposito, no hay atajo: es destructivo)
CONFIRM="$(yad --title="${YAD_TITLE}" --width=480 --center --entry \
    --text="Vas a BORRAR TODO en <b>${DISK}</b>.\n\nEscribe <b>${DISK}</b> exactamente para confirmar:")"
if [ "${CONFIRM}" != "${DISK}" ]; then
    yad --title="${YAD_TITLE}" --text="No coincide. Cancelado, no se toco nada." --button="Cerrar:0"
    exit 1
fi

# 4) Usuario y contrasena
FORM="$(yad --title="${YAD_TITLE}" --width=480 --center --form \
    --field="Nombre de usuario" "usuario" \
    --field="Contrasena:H" "" \
    --field="Repetir contrasena:H" "")"
[ -n "${FORM}" ] || exit 0
IFS='|' read -r NB_USER NB_PASS NB_PASS2 <<<"${FORM}"
if [ -z "${NB_USER}" ]; then
    yad --title="${YAD_TITLE}" --text="El nombre de usuario no puede estar vacio." --button="Cerrar:0"
    exit 1
fi
if [ "${NB_PASS}" != "${NB_PASS2}" ]; then
    yad --title="${YAD_TITLE}" --text="Las contrasenas no coinciden." --button="Cerrar:0"
    exit 1
fi

# 5) Instalar, con barra de progreso (indeterminada) mientras corre de verdad
LOGFILE="$(mktemp /tmp/niranbox-install.XXXXXX.log)"
(
    export NIRANBOX_ASSUME_YES=1
    export NIRANBOX_PASSWORD="${NB_PASS}"
    "${INSTALL_SCRIPT}" "${DISK}" "${NB_USER}" >"${LOGFILE}" 2>&1
    echo "$?" > "${LOGFILE}.rc"
) &
INSTALL_PID=$!

(
    while kill -0 "${INSTALL_PID}" 2>/dev/null; do
        echo "pulsate"
        sleep 1
    done
) | yad --title="${YAD_TITLE}" --width=480 --center --progress --pulsate \
        --text="Instalando NiranBox en ${DISK}...\nEsto puede tardar varios minutos." \
        --no-buttons --auto-close

wait "${INSTALL_PID}" 2>/dev/null
RC="$(cat "${LOGFILE}.rc" 2>/dev/null || echo 1)"

if [ "${RC}" = "0" ]; then
    yad --title="${YAD_TITLE}" --width=480 --center \
        --text="<b>Listo.</b> NiranBox quedo instalado en ${DISK}.\n\nAl reiniciar arranca directo a Steam. Para el Modo Escritorio (KDE Plasma), corre:\n<tt>steamos-session-select plasma</tt>" \
        --button="Reiniciar ahora:0" --button="Cerrar:1"
    if [ "$?" -eq 0 ]; then
        reboot
    fi
else
    yad --title="${YAD_TITLE}" --width=600 --height=400 --center \
        --text-info --filename="${LOGFILE}" \
        --text="Algo fallo durante la instalacion. Este es el detalle:" \
        --button="Cerrar:0"
fi
