#!/bin/bash

# Detect if running in Pterodactyl
# Pterodactyl typically has read-only /var/run and sets P_SERVER_UUID
PTERODACTYL_MODE=false
if [ -n "$P_SERVER_UUID" ] || [ ! -w "/var/run" ] 2>/dev/null; then
  PTERODACTYL_MODE=true
  echo "==> Running in Pterodactyl mode - bypassing s6-overlay"
  
  # Kill any s6-overlay processes that might be stuck
  pkill -9 s6 2>/dev/null || true
  pkill -9 s6-svscan 2>/dev/null || true
fi

# Note: HOME is set later based on deployment type (Pterodactyl vs standard)

# Ensure s6-overlay runtime directory exists and is writable (for Pterodactyl compatibility)
if [ "$PTERODACTYL_MODE" = false ]; then
  mkdir -p "${S6_RUNTIME_DIR:-/tmp/s6-runtime}"
  mkdir -p "${S6_RUNTIME_DIR:-/tmp/s6-runtime}/env-stage1"
  mkdir -p "${S6_RUNTIME_DIR:-/tmp/s6-runtime}/env-stage2"
  mkdir -p /etc/s6/init/env 2>/dev/null || true
  chmod -R 777 "${S6_RUNTIME_DIR:-/tmp/s6-runtime}" 2>/dev/null || true
  chmod -R 777 /etc/s6/init 2>/dev/null || true

  # For regular Docker: if /var/run/s6 doesn't exist or isn't a symlink, try to create it
  if [ ! -e "/var/run/s6" ] && [ -w "/var/run" ] 2>/dev/null; then
    rm -f /var/run/s6 2>/dev/null || true
    ln -sf /tmp/s6-runtime /var/run/s6 2>/dev/null || true
  elif [ -e "/var/run/s6" ] && [ ! -L "/var/run/s6" ]; then
    rm -rf /var/run/s6 2>/dev/null || true
    ln -sf /tmp/s6-runtime /var/run/s6 2>/dev/null || true
  fi

  # Ensure the symlink target has the required directories
  if [ -L "/var/run/s6" ]; then
    S6_TARGET=$(readlink -f /var/run/s6)
    mkdir -p "$S6_TARGET/env-stage1" "$S6_TARGET/env-stage2" 2>/dev/null || true
    chmod -R 777 "$S6_TARGET" 2>/dev/null || true
  fi
fi

# Create writable X11 socket directory
mkdir -p /tmp/.X11-unix
chmod 777 /tmp/.X11-unix 2>/dev/null || true

# Support Pterodactyl deployment - use /home/container for saves if it exists and is writable
if [ -d "/home/container" ] && [ -w "/home/container" ]; then
  echo "Pterodactyl deployment detected - using /home/container for saves"
  export SAVE_DIR="/home/container/Saves"
  export CONFIG_BASE="/home/container"
  export LOG_DIR="/home/container/xdg/config/StardewValley/ErrorLogs"
  # In Pterodactyl, override HOME to use writable directory
  export HOME=/home/container
  
  # Set XDG directories to /home/container for Pterodactyl
  export XDG_CONFIG_HOME="/home/container/xdg/config"
  export XDG_DATA_HOME="/home/container/xdg/data"
  export XDG_CACHE_HOME="/home/container/xdg/cache"
  export XDG_STATE_HOME="/home/container/xdg/state"
else
  echo "Standard deployment - using /config for saves"
  export SAVE_DIR="/config/xdg/config/StardewValley/Saves"
  export CONFIG_BASE="/config"
  export LOG_DIR="/config/xdg/config/StardewValley/ErrorLogs"
  export HOME=/config
  
  # Set XDG directories to /config for standard deployment
  export XDG_CONFIG_HOME="/config/xdg/config"
  export XDG_DATA_HOME="/config/xdg/data"
  export XDG_CACHE_HOME="/config/xdg/cache"
  export XDG_STATE_HOME="/config/xdg/state"
fi

# Create save directory and all XDG directories if they don't exist
mkdir -p "$SAVE_DIR"
mkdir -p "$LOG_DIR"
mkdir -p "$XDG_CONFIG_HOME"
mkdir -p "$XDG_DATA_HOME"
mkdir -p "$XDG_CACHE_HOME"
mkdir -p "$XDG_STATE_HOME"

# Link save directory to expected location if not already linked
# Only create symlink for standard deployments, not Pterodactyl
if [ ! -d "/home/container" ] || [ ! -w "/home/container" ]; then
  if [ ! -L "/config/xdg/config/StardewValley/Saves" ]; then
    mkdir -p /config/xdg/config/StardewValley
    ln -sf "$SAVE_DIR" /config/xdg/config/StardewValley/Saves
  fi
fi

# Handle mods based on deployment mode
if [ "$PTERODACTYL_MODE" = true ]; then
  echo "==> Pterodactyl mode: Preparing mods in /home/container"
  
  # In Pterodactyl mode, copy game files to writable directory if needed
  CONTAINER_GAME_DIR="$HOME/Stardew"
  
  # Check if we need to copy the game directory
  if [ ! -d "$CONTAINER_GAME_DIR/Stardew Valley" ]; then
    echo "==> Copying game files to $CONTAINER_GAME_DIR..."
    mkdir -p "$CONTAINER_GAME_DIR"
    cp -r "/data/Stardew/Stardew Valley" "$CONTAINER_GAME_DIR/"
    echo "==> Game files copied successfully"
  fi
  
  # Update GAME_DIR to point to writable location
  export GAME_DIR="$CONTAINER_GAME_DIR/Stardew Valley"
  
  # Configure mods in the writable directory
  if [ -d "$GAME_DIR/Mods/" ]; then
    for modPath in "$GAME_DIR/Mods/"*/
    do
      [ -d "$modPath" ] || continue
      mod=$(basename "$modPath")

      # Normalize mod name to uppercase and only characters
      var="ENABLE_$(echo "${mod^^}" | tr -cd '[A-Z]')_MOD"

      # Remove the mod if it's not enabled
      if [ "${!var}" != "true" ]; then
        echo "Removing ${modPath} (${var}=${!var})"
        rm -rf "$modPath"
        continue
      fi

      if [ -f "${modPath}/config.json.template" ]; then
        echo "Configuring ${modPath}config.json"
        if [ "$(cat "${modPath}config.json" 2> /dev/null)" == "" ]; then
          envsubst < "${modPath}config.json.template" > "${modPath}config.json"
        fi
      fi
    done
  fi
  
  echo "==> Mods configured in $GAME_DIR/Mods/"
elif [ -w "/data/Stardew/Stardew Valley/Mods/" ] 2>/dev/null; then
  # Standard mode with writable mods directory
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

  # Run extra steps for certain mods (only if writable)
  /opt/configure-remotecontrol-mod.sh
else
  echo "==> Skipping mod configuration (read-only filesystem)"
  echo "==> All mods will be loaded with default settings"
fi

# Start VNC services if in Pterodactyl mode
if [ "$PTERODACTYL_MODE" = true ]; then
  echo "==> Starting VNC services for Pterodactyl..."
  
  # Set default ports if not provided
  VNC_PORT="${VNC_PORT:-5900}"
  WEBVNC_PORT="${WEBVNC_PORT:-5800}"
  GAME_PORT="${GAME_PORT:-24642}"
  
  # Set VNC password (use writable directory)
  VNC_DIR="$HOME/.vnc"
  mkdir -p "$VNC_DIR"
  
  # VNC password configuration
  # x11vnc can use direct password with -passwd or encrypted file
  # We'll use x11vnc's built-in password option instead of vncpasswd
  if [ -n "$VNC_PASSWORD" ]; then
    # Create a simple VNC password file using Python (available in base image)
    python3 -c "import sys; sys.stdout.buffer.write(b'$VNC_PASSWORD\n')" 2>/dev/null || echo "$VNC_PASSWORD" > "$VNC_DIR/passwd.txt"
    chmod 600 "$VNC_DIR/passwd.txt" 2>/dev/null || true
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
  
  # Start x11vnc on the configured port
  VNC_LOG="$HOME/x11vnc.log"
  if [ -n "$VNC_PASSWORD" ]; then
    # Use direct password option (simpler and more reliable)
    x11vnc -display :0 -forever -shared -rfbport "$VNC_PORT" -passwd "$VNC_PASSWORD" -bg -o "$VNC_LOG" 2>&1
  else
    x11vnc -display :0 -forever -shared -rfbport "$VNC_PORT" -bg -o "$VNC_LOG" 2>&1
  fi
  echo "==> Started x11vnc on port $VNC_PORT (log: $VNC_LOG)"
  
  # Start noVNC (web VNC) if available
  if command -v websockify &> /dev/null; then
    websockify --web /usr/share/novnc "$WEBVNC_PORT" "localhost:$VNC_PORT" &>/dev/null &
    echo "==> Started Web VNC on port $WEBVNC_PORT"
  fi
  
  echo "==> Game server port: $GAME_PORT"
fi

/opt/tail-smapi-log.sh &

# Ensure DISPLAY is set (for both Pterodactyl and regular Docker modes)
export DISPLAY="${DISPLAY:-:0}"
# Ready to start!

export XAUTHORITY=~/.Xauthority
TERM=

# Start the game
# GAME_DIR is set earlier based on deployment mode:
# - Pterodactyl mode: /home/container/Stardew/Stardew Valley
# - Standard mode: /data/Stardew/Stardew Valley
if [ -z "$GAME_DIR" ]; then
  GAME_DIR="/data/Stardew/Stardew Valley"
fi
GAME_LAUNCHER="$GAME_DIR/StardewValley"

if [ -w "$GAME_LAUNCHER" ] 2>/dev/null; then
  # Standard mode: modify in place
  sed -i -e 's/env TERM=xterm $LAUNCHER "$@"$/env SHELL=\/bin\/bash TERM=xterm xterm  -e "\/bin\/bash -c $LAUNCHER "$@""/' "$GAME_LAUNCHER"
  bash -c "$GAME_LAUNCHER"
else
  # Pterodactyl mode: run from writable location with xterm wrapper
  # Change to game directory so SMAPI can find files
  cd "$GAME_DIR"
  
  # Create a wrapper script that runs the game from the correct directory
  WRAPPER_SCRIPT="$HOME/start_game.sh"
  cat > "$WRAPPER_SCRIPT" << EOFWRAPPER
#!/bin/bash
cd "$GAME_DIR"
export SHELL=/bin/bash
export TERM=xterm
export XAUTHORITY=~/.Xauthority
export HOME=$HOME
export XDG_CONFIG_HOME=$XDG_CONFIG_HOME
export XDG_DATA_HOME=$XDG_DATA_HOME
export XDG_CACHE_HOME=$XDG_CACHE_HOME
export XDG_STATE_HOME=$XDG_STATE_HOME

# Start xterm which will run SMAPI
exec xterm -e "/bin/bash -c 'cd \"$GAME_DIR\" && exec ./StardewModdingAPI'"
EOFWRAPPER
  
  chmod +x "$WRAPPER_SCRIPT"
  exec bash "$WRAPPER_SCRIPT"
fi

sleep 233333333333333
