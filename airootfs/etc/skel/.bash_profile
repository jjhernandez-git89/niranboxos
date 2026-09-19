# Sesion del USB live: arranca el instalador grafico propio (yad).
# El sistema ya instalado no usa este archivo -- ahi el login lo maneja SDDM
# (ver install/install-target.sh), directo a la sesion de juego.
if [ -z "${DISPLAY:-}" ] && [ "$(tty)" = "/dev/tty1" ]; then
    exec startx /usr/local/bin/xinitrc-niranbox-installer -- vt1
fi
