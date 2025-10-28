# Pterodactyl Deployment Guide

This guide explains how to deploy Stardew Valley multiplayer server on Pterodactyl panel.

## Prerequisites

- A Pterodactyl panel installation
- Access to create new servers

## Installation Steps

### 1. Import the Egg

1. Download the `egg-stardew-valley.json` file from this repository
2. In your Pterodactyl panel, go to **Admin Panel** → **Nests** → **Create New** (or select an existing nest)
3. Click **Import Egg** and upload the `egg-stardew-valley.json` file
4. The egg will be imported with all necessary configuration

### 2. Create a New Server

1. Go to **Servers** → **Create New**
2. Select the Stardew Valley egg you just imported
3. Configure the server settings:
   - **Server Name**: Choose a name for your server
   - **Allocations**: Pterodactyl will automatically assign ports
   - The egg is configured with default ports:
     - **Game Port**: 24642 (UDP) - Configurable in Startup tab
     - **VNC Port**: 5900 (TCP) - Configurable in Startup tab
     - **Web VNC Port**: 5800 (TCP) - Configurable in Startup tab
4. Set resource limits (recommended minimum):
   - **Memory**: 2048 MB (4096 MB recommended)
   - **CPU**: 200% (2 cores)
   - **Disk Space**: 5 GB

### 3. Configure Server Variables

After creating the server, you can configure various options through the server's **Startup** tab:

#### Port Settings
- **Game Port**: Port for the game server (default: `24642`)
- **VNC Port**: Port for VNC server access (default: `5900`)
- **Web VNC Port**: Port for browser-based VNC access (default: `5800`)

#### Essential Settings
- **VNC Password**: Password for VNC access (default: `nyanyanya`)
- **Display Width**: VNC display width (default: `1200`)
- **Display Height**: VNC display height (default: `900`)

#### Game Mods
- **Enable Always On Server**: Keeps the server running without players (default: `true`)
- **Enable Unlimited Players**: Allows more than 4 players (default: `true`)
- **Player Limit**: Maximum number of players (default: `10`)
- **Enable Auto Load Game**: Automatically loads the last save (default: `true`)
- **Enable Remote Control**: Enables remote server control (default: `true`)
- **Enable Save Backup**: Enables automatic save backups (default: `true`)

#### Game Settings
- **Auto Load Last File**: Name of the save file to auto-load (default: `null` for last played)
- **Load Into Multiplayer**: Automatically start multiplayer mode (default: `true`)
- **Time of Day to Sleep**: When the server should auto-sleep in 24h format (default: `2200`)

### 4. File Storage

All server data, including save files, will be stored in the `/home/container` directory:

- **Save Files**: `/home/container/Saves/`
- **Configuration**: `/home/container/xdg/config/StardewValley/`
- **Error Logs**: `/home/container/xdg/config/StardewValley/ErrorLogs/`

You can access these files through the Pterodactyl file manager or SFTP.

### 5. Initial Setup

1. Start the server from the Pterodactyl panel
2. The server will start on the configured ports (check console output for confirmation)
3. Console output will show:
   ```
   ==> Started x11vnc on port 5900
   ==> Started Web VNC on port 5800
   ==> Game server port: 24642
   ```
4. Access the game via VNC:
   - Use a VNC client (like TightVNC or RealVNC)
   - Connect to: `your-server-ip:vnc-port` (default: 5900)
   - Use the VNC password you set in the server variables
5. Alternatively, use the Web VNC interface:
   - Access: `http://your-server-ip:webvnc-port` (default: 5800)
   - This provides a browser-based interface
6. Create a new farm or load an existing save
7. Once loaded, the AutoLoad mod will remember this save and automatically load it on future restarts

## Troubleshooting

### Port Configuration

The ports are configurable in the **Startup** tab:
- **Game Port**: Default 24642 (UDP)
- **VNC Port**: Default 5900 (TCP)
- **Web VNC Port**: Default 5800 (TCP)

You can change these ports if needed for your Pterodactyl setup.

### Server Won't Start
- Check the server console for error messages
- Verify that all required ports are allocated
- Ensure sufficient memory is allocated (minimum 2GB)
- **s6-overlay 错误修复**: 如果您看到 `s6-hiercopy: fatal: unable to copy hierarchy from /etc/s6/init/env to /var/run/s6/env-stage1` 错误：
  - 这是由于 Pterodactyl 的文件系统限制导致的
  - 请确保您使用的是最新版本的镜像（包含 s6-overlay 修复）
  - 镜像已配置为使用 `/tmp/s6-runtime` 作为可写的替代目录
  - 如果问题持续存在，请尝试重新构建镜像
- **Note about s6-overlay warning**: If you see "s6-mkdir: warning: unable to mkdir /var/run/s6: Read-only file system", this can be safely ignored
  - The server is configured to use `/tmp/s6-runtime` as a writable alternative
  - The symlink `/var/run/s6 -> /tmp/s6-runtime` handles Pterodactyl's read-only filesystem restrictions
  - This warning does not affect server functionality

### Can't Connect via VNC
- Check the configured VNC port in the **Startup** tab (default: 5900)
- Verify the VNC password is set correctly in **Startup** variables
- Check the server console for "Started x11vnc on port XXXX" message
- Try using the Web VNC interface as an alternative (default port: 5800)
- If VNC services didn't start, try restarting the server
- Ensure the ports are not blocked by firewall rules

### Save Files Not Persisting
- Ensure the `/home/container` directory has proper permissions
- Check that the server has sufficient disk space
- Review the server logs for any error messages

### Performance Issues
- Increase CPU allocation (recommended: 200-400%)
- Increase memory allocation (recommended: 4GB)
- Reduce player limit if necessary
- Disable unnecessary mods

## Connecting to Your Server

Players can connect to your Stardew Valley server using:

1. **In-Game**: 
   - Open Stardew Valley
   - Go to Co-op → Join LAN Game
   - Enter the server's invite code (displayed in VNC)

2. **Direct Connection**:
   - The server runs on the allocated game port (default: 24642/udp)
   - Players need to forward this port or use direct IP connection

## Advanced Configuration

For more detailed configuration options, you can:

1. Access the server files via SFTP
2. Edit mod configuration files in `/home/container/Mods/`
3. Modify save files in `/home/container/Saves/`

## Support

For issues specific to this Pterodactyl setup, please open an issue on the GitHub repository.

For general Stardew Valley multiplayer questions, refer to the main README.md file.
