#!/bin/bash

# Detect if running in Pterodactyl
# Pterodactyl typically has read-only /var/run and sets P_SERVER_UUID
PTERODACTYL_MODE=false
if [ -n "$P_SERVER_UUID" ] || [ ! -w "/var/run" ] 2>/dev/null; then
  PTERODACTYL_MODE=true
  echo "==> Running in Pterodactyl mode"
fi

export HOME=/config

# Ensure s6-overlay runtime directory exists and is writable (for Pterodactyl compatibility)
mkdir -p "${S6_RUNTIME_DIR:-/tmp/s6-runtime}"
chmod 777 "${S6_RUNTIME_DIR:-/tmp/s6-runtime}" 2>/dev/null || true

# Create writable X11 socket directory
mkdir -p /tmp/.X11-unix
chmod 777 /tmp/.X11-unix 2>/dev/null || true

# Support Pterodactyl deployment - use /home/container for saves if it exists and is writable
if [ -d "/home/container" ] && [ -w "/home/container" ]; then
  echo "Pterodactyl deployment detected - using /home/container for saves"
  export SAVE_DIR="/home/container/Saves"
  export CONFIG_BASE="/home/container"
  export LOG_DIR="/home/container/xdg/config/StardewValley/ErrorLogs"
else
  echo "Standard deployment - using /config for saves"
  export SAVE_DIR="/config/xdg/config/StardewValley/Saves"
  export CONFIG_BASE="/config"
  export LOG_DIR="/config/xdg/config/StardewValley/ErrorLogs"
fi

# Create save directory if it doesn't exist
mkdir -p "$SAVE_DIR"
mkdir -p "$LOG_DIR"

# Link save directory to expected location if not already linked
# Only create symlink for standard deployments, not Pterodactyl
if [ ! -d "/home/container" ] || [ ! -w "/home/container" ]; then
  if [ ! -L "/config/xdg/config/StardewValley/Saves" ]; then
    mkdir -p /config/xdg/config/StardewValley
    ln -sf "$SAVE_DIR" /config/xdg/config/StardewValley/Saves
  fi
fi

for modPath in /data/Stardew/Stardew\ Valley/Mods/*/
do
  mod=$(basename "$modPath")

  # Normalize mod name to uppercase and only characters, eg. "Always On Server" => ENABLE_ALWAYSONSERVER_MOD
  var="ENABLE_$(echo "${mod^^}" | tr -cd '[A-Z]')_MOD"

  # Remove the mod if it's not enabled
  if [ "${!var}" != "true" ]; then
    echo "Removing ${modPath} (${var}=${!var})"
    rm -rf "$modPath"
    continue
  fi

  if [ -f "${modPath}/config.json.template" ]; then
    echo "Configuring ${modPath}config.json"

    # Seed the config.json only if one isn't manually mounted in (or is empty)
    if [ "$(cat "${modPath}config.json" 2> /dev/null)" == "" ]; then
      envsubst < "${modPath}config.json.template" > "${modPath}config.json"
    fi
  fi
done

# Run extra steps for certain mods
/opt/configure-remotecontrol-mod.sh

# Start VNC services if in Pterodactyl mode
if [ "$PTERODACTYL_MODE" = true ]; then
  echo "==> Starting VNC services for Pterodactyl..."
  
  # Set VNC password
  mkdir -p /config/.vnc
  if [ -n "$VNC_PASSWORD" ]; then
    echo "$VNC_PASSWORD" | vncpasswd -f > /config/.vnc/passwd
    chmod 600 /config/.vnc/passwd
    echo "==> VNC password configured"
  else
    echo "WARNING: No VNC_PASSWORD set, VNC may not work properly"
  fi
  
  # Start Xvfb (virtual X server)
  export DISPLAY=:0
  Xvfb :0 -screen 0 "${DISPLAY_WIDTH:-1200}x${DISPLAY_HEIGHT:-900}x24" -ac -nolisten tcp -nolisten unix &
  XVFB_PID=$!
  echo "==> Started Xvfb (PID: $XVFB_PID) at ${DISPLAY_WIDTH:-1200}x${DISPLAY_HEIGHT:-900}"
  
  # Wait for X server to be ready
  sleep 3
  
  # Start x11vnc
  if [ -f /config/.vnc/passwd ]; then
    x11vnc -display :0 -forever -shared -rfbport 5900 -rfbauth /config/.vnc/passwd -bg -o /config/x11vnc.log
  else
    x11vnc -display :0 -forever -shared -rfbport 5900 -bg -o /config/x11vnc.log
  fi
  echo "==> Started x11vnc on port 5900 (internal)"
  echo "==> Check Pterodactyl Network tab for external VNC port"
  
  # Start noVNC (web VNC) if available
  if command -v websockify &> /dev/null; then
    websockify --web /usr/share/novnc 5800 localhost:5900 &>/dev/null &
    echo "==> Started Web VNC on port 5800 (internal)"
    echo "==> Check Pterodactyl Network tab for external Web VNC port"
  fi
fi

/opt/tail-smapi-log.sh &

# Ensure DISPLAY is set (for both Pterodactyl and regular Docker modes)
export DISPLAY="${DISPLAY:-:0}"
# Ready to start!

export XAUTHORITY=~/.Xauthority
TERM=
sed -i -e 's/env TERM=xterm $LAUNCHER "$@"$/env SHELL=\/bin\/bash TERM=xterm xterm  -e "\/bin\/bash -c $LAUNCHER "$@""/' /data/Stardew/Stardew\ Valley/StardewValley

bash -c "/data/Stardew/Stardew\ Valley/StardewValley"

sleep 233333333333333
