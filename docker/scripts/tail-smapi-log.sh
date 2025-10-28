#!/bin/sh

echo "-- SMAPI Log: Starting"

# Use LOG_DIR from environment if set, otherwise detect deployment type
if [ -n "$LOG_DIR" ]; then
  LOG_PATH="$LOG_DIR/SMAPI-latest.txt"
elif [ -d "/home/container" ] && [ -w "/home/container" ]; then
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
