# Minecraft Server (Fabric + Cobblemon) — Run / Stop / Monitor

This document is the “daily operations” runbook for the Minecraft server installed in `/srv/minecraft`.

Install/setup is in `MINECRAFT_SERVER_INSTALL_VPS.md`.

---

## Key paths

- Server directory: `/srv/minecraft`
- Log file: `/srv/minecraft/logs/latest.log`
- Screen session name (recommended): `mc`

---

## Important: running as `minecraft` user

Admin-only tasks (firewall, packages, ownership) must be done as your admin user (`ubuntu`) with sudo.

The Minecraft process itself should run as the unprivileged `minecraft` user.

### Add permissions to minecraft user

If you copy or create files in `/srv/minecraft` as root, give ownership to the `minecraft` user so the server can read and write them. Example commands:

```bash
sudo chown -R minecraft:minecraft /srv/minecraft

# set sensible permissions (directories 755, files 644)
sudo find /srv/minecraft -type d -exec chmod 755 {} +
sudo find /srv/minecraft -type f -exec chmod 644 {} +
```

To check if any file or folder has not good permissions for minecraft

```bash
sudo find /srv/minecraft \( ! -user minecraft -o ! -group minecraft \) -ls
sudo find /srv/minecraft -type d ! -perm 0755 -ls
sudo find /srv/minecraft -type f ! -perm 0644 -ls
```

### If `sudo -i -u minecraft` “does nothing”

That typically means the `minecraft` account has a non-login shell (e.g. `/bin/false`).

Two options:

1. Keep it locked down and run commands as `minecraft` non-interactively:

```bash
sudo -u minecraft bash -c 'cd /srv/minecraft && <command>'
```

2. Allow interactive login by changing the shell:

```bash
sudo chsh -s /bin/bash minecraft
sudo -i -u minecraft
```

---

## Start (foreground)

```bash
sudo -u minecraft bash -c 'cd /srv/minecraft && java -Xms6G -Xmx6G -XX:+AlwaysPreTouch -XX:+DisableExplicitGC -jar fabric-server-mc.1.21.1-loader.0.18.0-launcher.1.1.0.jar nogui'
```

---

## Start (detached, survives SSH disconnect) with `screen`

### Create a detached session and run the server

```bash
sudo -u minecraft bash -c 'cd /srv/minecraft && screen -S mc -dm bash -lc "java -Xms6G -Xmx6G -XX:+AlwaysPreTouch -XX:+DisableExplicitGC -jar fabric-server-mc.1.21.1-loader.0.18.0-launcher.1.1.0.jar nogui"'
```

### Attach to the console

```bash
sudo -u minecraft screen -r mc
```

Detach from screen without stopping server:

- Press `Ctrl+A`, then `D`

---

## Stop (clean)

### Option A: attach and type `stop`

```bash
sudo -u minecraft screen -r mc
```

Then type:

```text
stop
```

### Option B: stop without attaching (send command to screen)

```bash
sudo -u minecraft screen -S mc -X stuff "stop\n"
```

If the session doesn’t exit after a few seconds, check logs. As a last resort, you can kill the `screen` session:

```bash
sudo -u minecraft screen -S mc -X quit
```

---

## See if it’s running

### Screen sessions

```bash
sudo -u minecraft screen -ls
```

### Process / PID

```bash
pgrep -af "fabric-server|minecraft|server\.jar"
```

### Listening port

```bash
sudo ss -ltnp | grep ":25565" || true
```

---

## Monitoring

### Live logs

```bash
sudo -u minecraft tail -F /srv/minecraft/logs/latest.log
```

### CPU/RAM quick view

```bash
ps -u minecraft -o pid,pcpu,pmem,etime,cmd --sort=-pcpu | head
```

### Interactive monitoring

```bash
top -u minecraft
```

Or install and use htop:

```bash
sudo apt install -y htop
htop
```

---

## Common fixes

### “Unknown command: stop<--[HERE]”

That happens when extra characters are sent. Ensure the command is exactly:

```text
stop
```

### Server doesn’t start after restart

Re-run from `/srv/minecraft` and watch the first error in `logs/latest.log`. Common causes:

- Java not installed / wrong Java version
- Corrupt download / missing libraries
- A mod is client-only or incompatible

---

## Notes

- `screen` persistence survives SSH disconnects, but not VPS reboot.
- If you ever want auto-start on reboot, that’s where systemd (or a supervisor) would come in—but you requested not to use it.
