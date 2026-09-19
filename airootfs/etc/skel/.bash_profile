# Sesion del USB live (arranca el instalador grafico Calamares).
# NOTA: install/install-target.sh y el paso final de Calamares SOBREESCRIBEN
# este archivo en el sistema ya instalado para que, en vez del instalador,
# arranque la sesion de juego (start-gamescope-session.sh).
if [ -z "${DISPLAY:-}" ] && [ "$(tty)" = "/dev/tty1" ]; then
    exec startx /usr/local/bin/xinitrc-niranbox-installer -- vt1
fi
