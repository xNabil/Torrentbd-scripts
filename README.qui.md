

---

## QUI — FRESH INSTALL (STEP-BY-STEP)

Assumptions
you are on Ubuntu / Debian VPS
You are root
Architecture: x86_64 (most VPS are)

# STEP 1 — Update system (basic hygiene)
```
apt update && apt upgrade -y
```

---

# STEP 2 — Install Qui (SINGLE LINE, RELIABLE)

```
cd /tmp && wget -O qui.tar.gz "$(curl -fsSL https://api.github.com/repos/autobrr/qui/releases/latest | grep linux_x86_64 | grep browser_download_url | cut -d\" -f4)" && tar -xzf qui.tar.gz && install -m 755 qui /usr/local/bin/qui
```
Verify:
```
qui version
```
If you see a version → good.


---

# STEP 3 — Generate Qui config (TOML, not YAML)

```
mkdir -p /etc/qui
qui generate-config --config-dir /etc/qui/config.toml
```

# STEP 4 — Edit config (IMPORTANT)
```
nano /etc/qui/config.toml
```
Find [server] and set host to "0.0.0.0" to connect from anywhere and a free port exactly:

[server]
host = "0.0.0.0"
port = 7476

Save and exit.


---


# STEP 5 — Create systemd service (DO NOT SKIP)

```
nano /etc/systemd/system/qui.service
```
Paste exactly:
```
[Unit]
Description=Qui - Unified qBittorrent Index
After=network.target

[Service]
User=root
Group=root
ExecStart=/usr/local/bin/qui serve --config-dir /etc/qui/
Restart=on-failure
RestartSec=5
LimitNOFILE=65536
WorkingDirectory=/etc/qui

[Install]
WantedBy=multi-user.target
```
Save and exit.


---

# STEP 6 — Enable & start Qui (systemd ONLY)

```
systemctl daemon-reload && systemctl enable --now qui
```
Check:
```
systemctl status qui
```
You want:

Active: active (running)


---

# STEP 7 — Verify port is open
```
ss -tulpen | grep 7476
```
Correct output:

*:7476

owned by qui

system.slice/qui.service



---

# STEP 8 — Open the Web UI

In browser:

http://YOUR_VPS_IP:7476

Log in with the user you created.


---

# STEP 9 — Reboot test (final proof)
```
sudo reboot
```
After reboot:

systemctl status qui

If it’s still running → installation is perfect.

