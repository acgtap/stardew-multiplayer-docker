#!/bin/bash

# Detect if running in Pterodactyl
# Pterodactyl typically has read-only /var/run and sets P_SERVER_UUID
PTERODACTYL_MODE=false
if [ -n "$P_SERVER_UUID" ] || [ ! -w "/var/run" ] 2>/dev/null; then
  PTERODACTYL_MODE=true
  echo "==> 正在翼龙模式下运行 - 跳过s6-overlay"
  
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
  echo "检测到翼龙部署 - 使用/home/container作为保存目录"
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
  echo "标准部署 - 使用/config作为保存目录"
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
  echo "==> 翼龙模式: 准备mods在/home/container"
  
  # In Pterodactyl mode, copy game files to writable directory if needed
  CONTAINER_GAME_DIR="$HOME/Stardew/Stardew Valley"
  
  # Check if we need to copy the game directory
  if [ ! -d "$CONTAINER_GAME_DIR" ]; then
    echo "==> 复制游戏文件到$CONTAINER_GAME_DIR..."
    echo "    Source: /data/Stardew/Stardew Valley"
    echo "    Destination: $HOME/Stardew/"
    
    # Ensure the parent directory exists
    mkdir -p "$HOME/Stardew"
    
    # Copy the game files (this will create /home/container/Stardew/Stardew Valley/)
    if [ -d "/data/Stardew/Stardew Valley" ]; then
      cp -r "/data/Stardew/Stardew Valley" "$HOME/Stardew/"
      echo "==> 游戏文件复制成功"
    else
      echo "ERROR: Source directory /data/Stardew/Stardew Valley not found!"
      exit 1
    fi
  else
    echo "==> 游戏文件已经存在 at $CONTAINER_GAME_DIR, 跳过复制"
  fi
  
  # Verify the game directory exists and show its contents
  if [ ! -d "$CONTAINER_GAME_DIR" ]; then
    echo "ERROR: 游戏目录 not found at $CONTAINER_GAME_DIR"
    echo "列出 $HOME/Stardew/:"
    ls -la "$HOME/Stardew/" 2>&1 || echo "Directory does not exist"
    exit 1
  fi
  
  echo "==> 游戏目录 verified at: $CONTAINER_GAME_DIR"
  echo "==> 游戏可执行文件应该在: $CONTAINER_GAME_DIR/StardewModdingAPI"
  
  # Update GAME_DIR to point to writable location
  export GAME_DIR="$CONTAINER_GAME_DIR"
  
  echo "==> 游戏目录 set to: $GAME_DIR"
  
  # Configure mods in the writable directory
  if [ -d "$GAME_DIR/Mods/" ]; then
    # List of built-in mods that should be controlled by environment variables
    BUILTIN_MODS=("ALOS" "AutoLoadGame" "ChatCommands" "ChangeServerPort" "ConsoleCommands" "CropsAnytimeAnywhere" "FriendsForever" "NoFenceDecay" "NonDestructiveNPCs" "RemoteControl" "ServerCMD" "TimeSpeed" "UnlimitedPlayers")
    
    for modPath in "$GAME_DIR/Mods/"*/
    do
      [ -d "$modPath" ] || continue
      mod=$(basename "$modPath")

      # Check if this is a built-in mod
      is_builtin=false
      for builtin_mod in "${BUILTIN_MODS[@]}"; do
        if [ "$mod" == "$builtin_mod" ]; then
          is_builtin=true
          break
        fi
      done

      # Only check environment variables for built-in mods
      if [ "$is_builtin" = true ]; then
        # Normalize mod name to uppercase and only characters
        var="ENABLE_$(echo "${mod^^}" | tr -cd '[A-Z]')_MOD"

        # Remove the built-in mod if it's not enabled
        if [ "${!var}" != "true" ]; then
          echo "删除内置mod ${modPath} (${var}=${!var})"
          rm -rf "$modPath"
          continue
        fi
        
        echo "启用内置mod: $mod"
      else
        echo "保留用户mod: $mod"
      fi

      # Configure mod if it has a template
      if [ -f "${modPath}/config.json.template" ]; then
        echo "配置 ${modPath}config.json"
        if [ "$(cat "${modPath}config.json" 2> /dev/null)" == "" ]; then
          envsubst < "${modPath}config.json.template" > "${modPath}config.json"
        fi
      fi
    done
  fi
  
  echo "==> mods 配置 in $GAME_DIR/Mods/"
elif [ -w "/data/Stardew/Stardew Valley/Mods/" ] 2>/dev/null; then
  # Standard mode with writable mods directory
  # List of built-in mods that should be controlled by environment variables
  BUILTIN_MODS=("ALOS" "AutoLoadGame" "ChatCommands" "ChangeServerPort" "ConsoleCommands" "CropsAnytimeAnywhere" "FriendsForever" "NoFenceDecay" "NonDestructiveNPCs" "RemoteControl" "ServerCMD" "TimeSpeed" "UnlimitedPlayers")
  
  for modPath in /data/Stardew/Stardew\ Valley/Mods/*/
  do
    mod=$(basename "$modPath")

    # Check if this is a built-in mod
    is_builtin=false
    for builtin_mod in "${BUILTIN_MODS[@]}"; do
      if [ "$mod" == "$builtin_mod" ]; then
        is_builtin=true
        break
      fi
    done

    # Only check environment variables for built-in mods
    if [ "$is_builtin" = true ]; then
      # Normalize mod name to uppercase and only characters, eg. "Always On Server" => ENABLE_ALWAYSONSERVER_MOD
      var="ENABLE_$(echo "${mod^^}" | tr -cd '[A-Z]')_MOD"

      # Remove the built-in mod if it's not enabled
      if [ "${!var}" != "true" ]; then
        echo "删除内置mod ${modPath} (${var}=${!var})"
        rm -rf "$modPath"
        continue
      fi
      
      echo "启用内置mod: $mod"
    else
      echo "保留用户mod: $mod"
    fi

    # Configure mod if it has a template
    if [ -f "${modPath}/config.json.template" ]; then
      echo "配置 ${modPath}config.json"

      # Seed the config.json only if one isn't manually mounted in (or is empty)
      if [ "$(cat "${modPath}config.json" 2> /dev/null)" == "" ]; then
        envsubst < "${modPath}config.json.template" > "${modPath}config.json"
      fi
    fi
  done

  # Run extra steps for certain mods (only if writable)
  /opt/configure-remotecontrol-mod.sh
else
  echo "==> 跳过mod配置 (只读文件系统)"
  echo "==> 所有mods 将使用默认设置加载"
fi

# Start VNC services if in Pterodactyl mode
if [ "$PTERODACTYL_MODE" = true ]; then
  echo "==> 启动VNC服务 for Pterodactyl..."
  
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
    echo "VNC密码: $VNC_PASSWORD"
    chmod 600 "$VNC_DIR/passwd.txt" 2>/dev/null || true
    echo "==> VNC 密码 配置成功"
  else
    echo "没有VNC_PASSWORD, VNC可能无法正常工作"
  fi
  
  # Start Xvfb (virtual X server)
  export DISPLAY=:0
  Xvfb :0 -screen 0 "${DISPLAY_WIDTH:-1200}x${DISPLAY_HEIGHT:-900}x24" -ac -nolisten tcp -nolisten unix &
  XVFB_PID=$!
  echo "==> 启动 Xvfb (PID: $XVFB_PID) at ${DISPLAY_WIDTH:-1200}x${DISPLAY_HEIGHT:-900}"
  
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
  echo "==> 启动 x11vnc on port $VNC_PORT (log: $VNC_LOG)"
  
  # Wait for x11vnc to be ready
  sleep 2
  
  # Verify x11vnc is running
  if pgrep -x x11vnc > /dev/null; then
    echo "==> x11vnc 进程运行正常"
  else
    echo "WARNING: x11vnc 进程未找到!"
    echo "==> x11vnc 日志:"
    tail -20 "$VNC_LOG" 2>/dev/null || echo "无法读取日志"
  fi
  
  # Start noVNC (web VNC) if available
  if command -v websockify &> /dev/null; then
    WEBSOCKIFY_LOG="$HOME/websockify.log"
    
    # Find noVNC web files in common locations
    NOVNC_PATH=""
    for path in /usr/share/novnc /usr/share/webapps/novnc /opt/novnc; do
      if [ -d "$path" ]; then
        NOVNC_PATH="$path"
        echo "==> 找到 noVNC web 文件: $NOVNC_PATH"
        break
      fi
    done
    
    # Start websockify with or without web files
    if [ -n "$NOVNC_PATH" ]; then
      websockify --daemon --log-file="$WEBSOCKIFY_LOG" --web "$NOVNC_PATH" "$WEBVNC_PORT" "localhost:$VNC_PORT"
    else
      echo "WARNING: 未找到 noVNC web 文件，启动纯 WebSocket 代理模式"
      echo "         您需要使用 VNC 客户端连接到端口 $VNC_PORT"
      websockify --daemon --log-file="$WEBSOCKIFY_LOG" "$WEBVNC_PORT" "localhost:$VNC_PORT"
    fi
    
    # Wait a moment and check if websockify started
    sleep 1
    if pgrep -f "websockify.*$WEBVNC_PORT" > /dev/null; then
      if [ -n "$NOVNC_PATH" ]; then
        echo "==> 启动 Web VNC on port $WEBVNC_PORT (浏览器访问)"
        echo "    访问: http://服务器IP:$WEBVNC_PORT/vnc.html"
      else
        echo "==> 启动 WebSocket 代理 on port $WEBVNC_PORT"
      fi
      echo "    日志: $WEBSOCKIFY_LOG"
    else
      echo "ERROR: websockify 启动失败!"
      echo "==> websockify 日志:"
      cat "$WEBSOCKIFY_LOG" 2>/dev/null || echo "无法读取日志"
    fi
  else
    echo "==> 未找到websockify, Web VNC不可用"
  fi
  
  echo "==> 游戏服务器端口: $GAME_PORT"
fi


# 将游戏端口写入/
# home
# /
# container
# /
# Stardew
# /
# Stardew Valley
# /
# Mods
# /
# ChangeServerPort
# /config.txt

echo "$GAME_PORT" > "$HOME/Stardew/Stardew Valley/Mods/ChangeServerPort/config.txt"
# 向Saves目录写入一个文件说明存档目录在xdg/config/StardewValley/Saves
echo "存档文件在xdg/config/StardewValley/Saves目录" > "$HOME/Saves/请读我存档不在这.txt"

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
GAME_LAUNCHER="$GAME_DIR/Stardew Valley/Stardew Valley"

if [ -w "$GAME_LAUNCHER" ] 2>/dev/null; then
  # Standard mode: modify in place
  sed -i -e 's/env TERM=xterm $LAUNCHER "$@"$/env SHELL=\/bin\/bash TERM=xterm xterm  -e "\/bin\/bash -c $LAUNCHER "$@""/' "$GAME_LAUNCHER"
  bash -c "$GAME_LAUNCHER"
else
  # Pterodactyl mode: run from writable location
  # Change to game directory so SMAPI can find files
  cd "$GAME_DIR"
  
  # Check if we should use interactive mode (allow console input)
  if [ "$ENABLE_CONSOLE_INPUT" = "true" ]; then
    echo "==> 启用控制台输入模式 - 您可以在翼龙面板输入SMAPI命令"
    # Run SMAPI directly without xterm to allow stdin/stdout
    exec ./StardewModdingAPI
  else
    # Default mode: use xterm wrapper (no console input, but more stable)
    echo "==> 使用 xterm 模式 - 控制台输入不可用，使用 VNC 或启用 ENABLE_CONSOLE_INPUT"
    # Create a wrapper script that runs the game from the correct directory
    WRAPPER_SCRIPT="$HOME/start_game.sh"
    
    # Use a different heredoc delimiter to avoid variable expansion issues
    cat > "$WRAPPER_SCRIPT" <<EOF
#!/bin/bash
cd "$GAME_DIR"
export SHELL=/bin/bash
export TERM=xterm
export XAUTHORITY=~/.Xauthority
export HOME="$HOME"
export XDG_CONFIG_HOME="$XDG_CONFIG_HOME"
export XDG_DATA_HOME="$XDG_DATA_HOME"
export XDG_CACHE_HOME="$XDG_CACHE_HOME"
export XDG_STATE_HOME="$XDG_STATE_HOME"

# Start xterm which will run SMAPI
exec xterm -e "/bin/bash -c 'cd \"$GAME_DIR\" && exec ./StardewModdingAPI'"
EOF
    
    chmod +x "$WRAPPER_SCRIPT"
    exec bash "$WRAPPER_SCRIPT"
  fi
fi

sleep 233333333333333
