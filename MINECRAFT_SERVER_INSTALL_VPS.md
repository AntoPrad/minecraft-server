# Minecraft Server (Fabric + Cobblemon) — Install on VPS

This document contains the installation / setup steps for a **Minecraft 1.21.1 Fabric** server with **Cobblemon Modpack [Fabric] 1.7.1**.

It intentionally does **not** cover daily operations (run/stop/monitor). See `MINECRAFT_SERVER_RUN_STOP_MONITOR.md`.

---

## Assumptions

- VPS: Ubuntu (OVH VPS, 4 vCPU / 8 GB RAM)
- Web stack (nginx reverse proxy + docker-compose) stays on ports 80/443
- Minecraft runs on **TCP 25565**

---

## 0) Users, folder, and Java

### Create the server folder

Run as your admin user (e.g. `ubuntu`) with sudo:

```bash
sudo mkdir -p /srv/minecraft
```

### Create the `minecraft` user (recommended)

```bash
sudo useradd -m -r -s /bin/bash minecraft || true
sudo chown -R minecraft:minecraft /srv/minecraft
```

If you prefer `minecraft` to be non-login (more locked down), it may end up with `/bin/false`. That is OK: you can still run commands as `minecraft` using `sudo -u minecraft ...`.

Check shell:

```bash
getent passwd minecraft
```

### Install Java (Minecraft 1.21.x uses Java 21)

```bash
sudo apt update
sudo apt install -y openjdk-21-jre-headless curl unzip screen python3
java -version
```

---

## 1) Upload the modpack file to the VPS

You used the Modrinth pack file:

- `Cobblemon Modpack [Fabric] 1.7.1.mrpack`

Example upload from your PC to the VPS:

```bash
scp "Cobblemon Modpack [Fabric] 1.7.1.mrpack" ubuntu@<VPS_IP>:/tmp/cobblemon.mrpack
```

Move it into the server folder:

```bash
sudo mv /tmp/cobblemon.mrpack "/srv/minecraft/Cobblemon Modpack [Fabric] 1.7.1.mrpack"
sudo chown minecraft:minecraft "/srv/minecraft/Cobblemon Modpack [Fabric] 1.7.1.mrpack"
```

---

## 2) Install / generate the Fabric server runtime

You have the Fabric server launcher jar:

- `fabric-server-mc.1.21.1-loader.0.18.4-launcher.1.1.1.jar`

Place it into `/srv/minecraft` (same method as the `.mrpack`), then run it once to download server files and libraries:

```bash
sudo -u minecraft bash -c 'cd /srv/minecraft && java -Xms4G -Xmx6G -jar fabric-server-mc.1.21.1-loader.0.18.4-launcher.1.1.1.jar nogui'
```

This step creates folders like `libraries/`, `versions/`, and generates `server.properties`.

---

## 3) Accept the Minecraft EULA

```bash
sudo -u minecraft bash -c 'cd /srv/minecraft && printf "eula=true\n" > eula.txt && cat eula.txt'
```

---

## 4) Install the modpack contents from the `.mrpack`

This command:

- reads the pack manifest (`modrinth.index.json`)
- downloads all listed files that are **not** marked as client-only (`env.server == unsupported`)
- verifies SHA-512 hashes when present
- extracts `overrides/` (configs, etc.) into `/srv/minecraft`

Run as `minecraft` from `/srv/minecraft`:

```bash
sudo -u minecraft bash -c 'cd /srv/minecraft && python3 - <<"PY"
import json, os, zipfile, hashlib, urllib.request

pack = "Cobblemon Modpack [Fabric] 1.7.1.mrpack"

def download(url, dest_path, expected_sha512=None):
    os.makedirs(os.path.dirname(dest_path) or ".", exist_ok=True)
    with urllib.request.urlopen(url) as r, open(dest_path, "wb") as f:
        h = hashlib.sha512() if expected_sha512 else None
        while True:
            chunk = r.read(1024 * 1024)
            if not chunk:
                break
            f.write(chunk)
            if h:
                h.update(chunk)
    if expected_sha512:
        got = h.hexdigest()
        if got != expected_sha512:
            raise SystemExit(f"SHA512 mismatch for {dest_path}")

z = zipfile.ZipFile(pack)
idx = json.loads(z.read("modrinth.index.json"))

print("Installing pack:", idx.get("name"))
print("Dependencies:", idx.get("dependencies"))

count = 0
for entry in idx.get("files", []):
    env = entry.get("env", {})
    if env.get("server") == "unsupported":
        continue
    path = entry["path"]
    url = entry["downloads"][0]
    sha512 = entry.get("hashes", {}).get("sha512")
    download(url, path, sha512)
    count += 1

print("Downloaded files:", count)

names = z.namelist()
if any(n.startswith("overrides/") for n in names):
    for n in names:
        if n.startswith("overrides/") and not n.endswith("/"):
            target = n[len("overrides/"):]
            os.makedirs(os.path.dirname(target) or ".", exist_ok=True)
            with open(target, "wb") as f:
                f.write(z.read(n))
    print("Extracted overrides/")
else:
    print("No overrides/ folder in pack.")
PY'
```

Sanity check:

```bash
sudo -u minecraft bash -c 'ls -la /srv/minecraft/mods | head'
```

---

## 5) Open firewall port (UFW + OVH)

Run as admin user (`ubuntu`):

```bash
sudo ufw allow 25565/tcp
sudo ufw status verbose
```

Also ensure OVH firewall (control panel) allows inbound TCP 25565.

---

## 6) Verify server can bind the port

Start once (foreground) and confirm you see `Starting Minecraft server on *:25565` and `Done (...)!`:

```bash
sudo -u minecraft bash -c 'cd /srv/minecraft && java -Xms4G -Xmx6G -jar fabric-server-mc.1.21.1-loader.0.18.4-launcher.1.1.1.jar nogui'
```

Then stop cleanly by typing `stop` in the server console.
