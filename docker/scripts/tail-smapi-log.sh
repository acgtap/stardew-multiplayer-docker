#!/bin/sh

echo "-- SMAPI Log: Starting"

# Support both standard and Pterodactyl deployments
if [ -d "/home/container" ] && [ -w "/home/container" ]; then
  LOG_PATH="/home/container/xdg/config/StardewValley/ErrorLogs/SMAPI-latest.txt"
else
  LOG_PATH="/config/xdg/config/StardewValley/ErrorLogs/SMAPI-latest.txt"
fi

# Wait for SMAPI log and tail infinitely
while [ ! -f "$LOG_PATH" ]; do
  echo "-- SMAPI Log: Waiting for log to appear at $LOG_PATH";
  sleep 5;
done

echo "-- SMAPI Log: Tailing $LOG_PATH"
tail -f "$LOG_PATH"
