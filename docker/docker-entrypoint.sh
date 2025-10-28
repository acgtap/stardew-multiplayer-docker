#!/bin/bash
export HOME=/config

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
if [ ! -L "/config/xdg/config/StardewValley/Saves" ]; then
  mkdir -p /config/xdg/config/StardewValley
  ln -sf "$SAVE_DIR" /config/xdg/config/StardewValley/Saves
fi

for modPath in /data/Stardew/Stardew\ Valley/Mods/*/
do
  mod=$(basename "$modPath")

  # Normalize mod name ot uppercase and only characters, eg. "Always On Server" => ENABLE_ALWAYSONSERVER_MOD
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

/opt/tail-smapi-log.sh &

# Ready to start!

export XAUTHORITY=~/.Xauthority
TERM=
sed -i -e 's/env TERM=xterm $LAUNCHER "$@"$/env SHELL=\/bin\/bash TERM=xterm xterm  -e "\/bin\/bash -c $LAUNCHER "$@""/' /data/Stardew/Stardew\ Valley/StardewValley

bash -c "/data/Stardew/Stardew\ Valley/StardewValley"

sleep 233333333333333
