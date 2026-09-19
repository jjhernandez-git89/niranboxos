#!/usr/bin/env bash
# Lanza la sesion "modo consola" NiranBox: gamescope como compositor Wayland
# embebido, con Steam arrancando directo en Big Picture (-tenfoot).
set -u

export XDG_RUNTIME_DIR="/run/user/$(id -u)"
mkdir -p "${XDG_RUNTIME_DIR}"

exec gamescope \
  --backend drm \
  -W 1920 -H 1080 \
  -f \
  --mangoapp \
  -- \
  steam -tenfoot -pipewire-dmabuf -steamdeck -steamos3
