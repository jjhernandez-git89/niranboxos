#!/usr/bin/env bash
# Ultimo paso de Calamares (modulo shellprocess), corriendo YA en el disco
# instalado (chroot). $1 = nombre de usuario que la persona eligio en el
# instalador. Convierte el sistema (que hasta aqui es una copia 1:1 del USB
# live, instalador incluido) en el NiranBox final: SDDM con autologin directo
# a Steam (modo consola), con Modo Escritorio (KDE Plasma) a un
# "steamos-session-select plasma" de distancia.
set -e -u
USERNAME="${1:?falta el usuario}"

echo "==> NiranBox: configurando sesiones para '${USERNAME}'"

# La cuenta 'deck' solo existia para arrancar el instalador desde el USB live.
if id deck >/dev/null 2>&1; then
    userdel -r deck 2>/dev/null || true
fi

# sudo sin password para el usuario final (como en Steam Deck / modo consola).
# Tambien lo necesita steamos-session-select para cambiar de sesion.
echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/10-wheel-nopasswd
chmod 440 /etc/sudoers.d/10-wheel-nopasswd

# El instalador (getty autologin en tty1) ya no aplica: de aqui en adelante
# el login lo maneja SDDM, con dos sesiones (gamescope y plasma).
rm -rf /etc/systemd/system/getty@tty1.service.d

mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/autologin.conf <<EOF
[Autologin]
User=${USERNAME}
Session=gamescope-session.desktop
Relogin=true
EOF

# Tema de SDDM: pantalla de login con el logo de NiranBox (solo se ve si en
# algun momento el autologin falla o se desactiva; en uso normal no se llega
# a ver, porque autologin entra directo).
mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/theme.conf <<'EOF'
[Theme]
Current=breeze
EOF

# Splash de arranque Plymouth con el logo de NiranBox.
if ! grep -qE '^HOOKS=\([^)]*\bplymouth\b' /etc/mkinitcpio.conf; then
    sed -i -E 's/^(HOOKS=\([^)]*udev)/\1 plymouth/' /etc/mkinitcpio.conf
fi
plymouth-set-default-theme -R niranbox || true

# Limpieza: el instalador grafico y el repo de terceros que lo trajo
# (Chaotic-AUR) ya no hacen falta en el sistema final.
pacman -Rns --noconfirm calamares xorg-server xorg-xinit xorg-xsetroot \
    chaotic-keyring chaotic-mirrorlist 2>/dev/null || true
sed -i '/^\[chaotic-aur\]/,+1 s/^/#/' /etc/pacman.conf 2>/dev/null || true

echo "==> NiranBox: listo. Al reiniciar entra directo a Steam."
echo "    Para el Modo Escritorio (KDE Plasma): steamos-session-select plasma"
