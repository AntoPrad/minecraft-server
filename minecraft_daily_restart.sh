#!/usr/bin/env bash
set -euo pipefail

# Minecraft server control script
# MINECRAFT_SERVER=true|false (default: false)

MINECRAFT_SERVER="${MINECRAFT_SERVER:-false}"
SERVER_DIR="/srv/minecraft"
MCR_USER="minecraft"
SCREEN_NAME="mc"
START_CMD="java -Xms4G -Xmx5G -XX:+UseG1GC -jar fabric-server-mc.1.21.1-loader.0.18.0-launcher.1.1.0.jar nogui"
KILL_PATTERN="fabric-server-mc\.1\.21\.1-loader\.0\.18\.0-launcher\.1\.1\.0\.jar"

log() { echo "$(date --iso-8601=seconds) $*"; }

MINECRAFT_SERVER=$(echo "$MINECRAFT_SERVER" | tr '[:upper:]' '[:lower:]')

screen_running() {
  sudo -u "$MCR_USER" screen -ls 2>/dev/null |
    grep -Eq "\.${SCREEN_NAME}\b|\b${SCREEN_NAME}\b"
}

stop_server() {
  log "Stopping server"

  # Find all matching screen sessions (mc or PID.mc)
  sessions=$(sudo -u "$MCR_USER" screen -ls 2>/dev/null |
    awk '{print $1}' |
    grep -E "(\.${SCREEN_NAME}$|^${SCREEN_NAME}$)" || true)

  if [ -n "$sessions" ]; then
    for s in $sessions; do
      log "Sending stop to screen session $s"
      sudo -u "$MCR_USER" screen -S "$s" -X stuff "stop\n" || true
    done
  else
    log "No screen session found"
  fi

  timeout=20
  while screen_running && [ "$timeout" -gt 0 ]; do
    sleep 5
    timeout=$((timeout-5))
  done

  if screen_running; then
    log "Graceful stop failed, terminating process"
    sudo pkill -TERM -u "$MCR_USER" -f "$KILL_PATTERN" || true
    sleep 5
    sudo pkill -KILL -u "$MCR_USER" -f "$KILL_PATTERN" || true
  else
    log "Server stopped"
  fi
}

start_server() {
  log "Starting server"

  if screen_running; then
    log "Server already running"
    return 0
  fi

  sudo -u "$MCR_USER" bash -c \
    "cd '$SERVER_DIR' && screen -S '$SCREEN_NAME' -dm bash -lc \"$START_CMD\""

  sleep 5

  if screen_running; then
    log "Server started"
  else
    log "Server failed to start"
    return 1
  fi
}

case "$MINECRAFT_SERVER" in
  true)
    stop_server
    start_server
    ;;
  false)
    stop_server
    ;;
  *)
    log "Invalid MINECRAFT_SERVER='$MINECRAFT_SERVER' (expected true or false)"
    exit 2
    ;;
esac

exit 0
