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
   - **Allocations**: Assign **3 ports** (required):
     - **Primary Port**: Game server (default: 24642/udp) - This will be auto-assigned as the main allocation
     - **Additional Port 1**: VNC server (default: 5900/tcp) - For VNC client access
     - **Additional Port 2**: Web VNC (default: 5800/tcp) - For browser-based VNC access
   - **Important**: Make sure to add 2 additional port allocations beyond the primary port
4. Set resource limits (recommended minimum):
   - **Memory**: 2048 MB (4096 MB recommended)
   - **CPU**: 200% (2 cores)
   - **Disk Space**: 5 GB

### 3. Configure Server Variables

After creating the server, you can configure various options through the server's **Startup** tab:

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
2. Wait for the server to start (you should see "Started x11vnc on port 5900" and "SMAPI ready" in the console)
3. Find your VNC port:
   - Go to your server's **Network** tab in Pterodactyl
   - Look for the port allocation labeled for VNC (the second port after the game port)
   - This is the external port you'll use to connect
4. Access the game via VNC:
   - Use a VNC client (like TightVNC or RealVNC)
   - Connect to: `your-server-ip:vnc-external-port`
   - Use the VNC password you set in the server variables
5. Alternatively, use the Web VNC interface:
   - Find the Web VNC port (third port) in the **Network** tab
   - Access: `http://your-server-ip:web-vnc-external-port`
   - This provides a browser-based interface
6. Create a new farm or load an existing save
7. Once loaded, the AutoLoad mod will remember this save and automatically load it on future restarts

## Troubleshooting

### Finding VNC Ports

The VNC ports in Pterodactyl are dynamically assigned:

1. Go to your server's **Network** tab
2. You'll see multiple port allocations:
   - **Primary Allocation**: Game server port (UDP)
   - **Additional Allocation 1**: VNC port (TCP) - typically 5900 internally
   - **Additional Allocation 2**: Web VNC port (TCP) - typically 5800 internally
3. The external ports shown in the Network tab are what you use to connect
4. Example: If the Network tab shows `192.168.1.100:25565` for VNC, connect to `192.168.1.100:25565` with your VNC client

### Server Won't Start
- Check the server console for error messages
- Verify that all required ports are allocated
- Ensure sufficient memory is allocated (minimum 2GB)

### Can't Connect via VNC
- Verify the VNC port is allocated in the **Network** tab
- Check that the VNC password is set correctly in **Startup** variables
- Ensure you're using the external port shown in the Network tab, not the internal port
- Check the server console for "Started x11vnc on port 5900" message
- Try using the Web VNC interface as an alternative
- If VNC services didn't start, try restarting the server

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
