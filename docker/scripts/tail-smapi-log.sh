#!/bin/bash

echo "-- SMAPI Log: Starting"

# Use LOG_DIR from environment if set, otherwise detect deployment type
if [ -n "$LOG_DIR" ]; then
  LOG_PATH="$LOG_DIR/SMAPI-latest.txt"
elif [ -d "/home/container" ] && [ -w "/home/container" ]; then
  LOG_PATH="/home/container/xdg/config/StardewValley/ErrorLogs/SMAPI-latest.txt"
else
  LOG_PATH="/config/xdg/config/StardewValley/ErrorLogs/SMAPI-latest.txt"
fi

echo "-- SMAPI Log: 日志路径设置为 $LOG_PATH"

# Create log directory if it doesn't exist
LOG_DIR_PATH=$(dirname "$LOG_PATH")
if [ ! -d "$LOG_DIR_PATH" ]; then
  echo "-- SMAPI Log: 创建日志目录 $LOG_DIR_PATH"
  mkdir -p "$LOG_DIR_PATH" 2>&1
fi

# Wait for SMAPI log with timeout and better feedback
MAX_WAIT=60  # Maximum wait time in seconds (12 * 5 = 60 seconds)
WAIT_COUNT=0

while [ ! -f "$LOG_PATH" ]; do
  echo "-- SMAPI Log: 等待日志文件出现... ($WAIT_COUNT/$MAX_WAIT 秒)"
  echo "-- SMAPI Log: 检查路径: $LOG_PATH"
  
  # Show directory contents for debugging
  if [ -d "$LOG_DIR_PATH" ]; then
    echo "-- SMAPI Log: 目录内容:"
    ls -la "$LOG_DIR_PATH" 2>&1 | head -10
  else
    echo "-- SMAPI Log: 警告 - 日志目录不存在: $LOG_DIR_PATH"
  fi
  
  sleep 5
  WAIT_COUNT=$((WAIT_COUNT + 5))
  
  if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
    echo "-- SMAPI Log: 警告 - 等待超时，但继续尝试..."
    # Don't exit, keep trying
  fi
done

echo "-- SMAPI Log: 找到日志文件！开始跟踪 $LOG_PATH"
echo "-- SMAPI Log: ======================================"

# Use tail with explicit options to ensure it keeps running
# -f: follow the file
# -n 0: don't show existing lines (only new ones)
# --retry: keep trying if file is inaccessible
# 2>&1: redirect stderr to stdout to capture any errors
exec tail -f -n 100 --retry "$LOG_PATH" 2>&1
