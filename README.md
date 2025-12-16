# Torrent Auto Description Maker

A ruthless little automation that turns a video or a full season folder into a **ready-to-post TorrentBD description** — screenshots uploaded, MediaInfo embedded, torrent created, BBCode polished, clipboard loaded.

You select.
It works.
You post.

Built for people who are tired of doing the same ritual by hand.

---

## What This Script Does

This tool automates the boring, error-prone parts of torrent posting:

* 🎞️ Select **one video** or an **entire folder**
* 🧠 Auto-picks a video (folder mode) for:

  * MediaInfo extraction
  * Screenshot capture
* 📸 Takes **lossless screenshots** (PNG → smart fallback to JPG if host limits are hit)
* ☁️ Uploads screenshots to:

  * **freeimage.host** (64 MB limit)
  * **imgbb** (32 MB limit)
* ⚡ Uploads screenshots **in parallel** (fast, no mercy)
* 🧾 Builds a **clean BBCode description**:

  * MediaInfo section
  * Screenshot section
  * Styled headers & footer
* 📋 Copies the final description **directly to clipboard**
* 🌊 Optionally creates a **private .torrent file** using `mkbrr`

End result:
**Paste → Seed → Done.**

---

## Why This Exists

Because:

* Manual screenshots are a waste of neurons
* Re-uploading failed PNGs is pain
* Formatting BBCode by hand is medieval
* Consistency matters on private trackers

This script removes friction.
You focus on releases, not rituals.

---


Alright — here’s the **drop-in README section** you can add.
Blunt, practical, zero hand-holding nonsense.

You can paste this **as-is** under a **“Setup & Requirements”** heading.

---

## Setup & Requirements

This script relies on **external tools**.
If they’re not installed **and added to PATH**, the script will fail. No magic.

### 1. Python

* **Python 3.9 or newer**
* Verify:

```bash
python --version
```

Install dependency:

```bash
pip install requests
```

---

## Required External Tools (Must Be in PATH)

### FFmpeg (ffmpeg + ffprobe)

Used for:

* Video duration detection
* Frame-accurate screenshots

**Download**

* [https://ffmpeg.org/download.html](https://ffmpeg.org/download.html)

**Windows setup**

1. Download static build
2. Extract (e.g. `C:\ffmpeg`)
3. Add `C:\ffmpeg\bin` to **System PATH**
4. Restart terminal

**Verify**

```bash
ffmpeg -version
ffprobe -version
```

If this fails, screenshots will fail. Period.

---

### MediaInfo

Used to extract **full MediaInfo text** for BBCode.

**Download**

* [https://mediaarea.net/en/MediaInfo](https://mediaarea.net/en/MediaInfo)

**Windows**

* Install normally **OR**
* Place `MediaInfo.exe` in the same folder as the script

**Linux**

```bash
sudo apt install mediainfo
```

**Verify**

```bash
mediainfo --version
```

---

### mkbrr (Torrent Creator)

Used to generate `.torrent` files.

**Download**

* [https://github.com/autobrr/mkbrr](https://github.com/autobrr/mkbrr)

**Windows**

1. Download release
2. Place `mkbrr.exe` somewhere permanent
3. Add that folder to **PATH**

**Linux / macOS**

```bash
sudo mv mkbrr /usr/local/bin
chmod +x /usr/local/bin/mkbrr
```

**Verify**

```bash
mkbrr --version
```

If `mkbrr` is missing:

* Torrent creation will fail
* Script will warn and stop (if enabled)

---

## API Keys Setup

### freeimage.host (Default – No Account Needed)

* Uses a **public API key**
* No signup required
* No account binding
* No quota guarantees

Already included in the script:

```python
FREEIMAGE_API_KEY = "6d207e02198a847aa98d0a2a901485a5"
IMAGE_HOST = "freeimage"
```

⚠ This key is **shared and public**
If freeimage.host changes or rate-limits it, uploads may break.

That’s the trade-off.

---

### imgbb (Optional – More Stable)

* Requires your own API key
* Lower file size limit (32 MB)
* More reliable long-term

**Get API Key**

1. Go to [https://imgbb.com](https://imgbb.com)
2. Create account
3. Visit: [https://api.imgbb.com](https://api.imgbb.com)
4. Generate API key

**Set in script**

```python
IMGBB_API_KEY = "YOUR_API_KEY_HERE"
IMAGE_HOST = "imgbb"
```

If `IMGBB_API_KEY` is not set → uploads will fail silently for imgbb.

---

## PATH Sanity Check (Important)

Before running the script, **all of these must work**:

```bash
ffmpeg -version
ffprobe -version
mediainfo --version
mkbrr --version
```

If even one fails:

* Fix PATH
* Restart terminal
* Try again

## Configuration (Read This)

At the top of the script:

```python

# ========================= CONFIGURATION =========================
IMGBB_API_KEY = "YOUR IMGBB API KEY"   # CHANGE THIS! (Revoke the old one if exposed!)
FREEIMAGE_API_KEY = "Your Freeimge key"

IMAGE_HOST = "freeimage"               # "imgbb" or "freeimage"
                                       # imgbb → max file size 32 MB
                                       # freeimage → max file size 64 MB

SCREENSHOT_COUNT = 6
LOSSLESS_SCREENSHOT = True             # True = PNG (fallback to JPG if > max size of chosen host) | False = Always JPG
CREATE_TORRENT_FILE = True             # False = Skip .torrent creation
SKIP_TXT = True                        # True = Don't save .txt file (but still copy to clipboard)
TRACKER_ANNOUNCE = "https://tracker.torrentbd.net/announce"
PRIVATE_TORRENT = True
COPY_TO_CLIPBOARD = True
USE_WP_PROXY = False                   # True = Use https://i1.wp.com/ proxy | False = Direct link
# ================================================================

```

### Image Host Limits

* **imgbb** → 32 MB max
* **freeimage.host** → 64 MB max

PNG too big?
The script **automatically falls back to JPG**. No babysitting.

---

## How It Works (Flow)

1. Launch script
2. Choose:

   * Single video **or**
   * Folder (season / batch)
3. Torrent file created (`.torrent`)
4. Screenshots taken between **20% → 80%** of runtime
5. Screenshots uploaded concurrently
6. BBCode description generated
7. Description copied to clipboard
8. Temporary files cleaned
9. You post. The tracker smiles.

---

## Output

* 📋 **Clipboard** → Full TorrentBD-ready BBCode
* 📁 Optional `.torrent` file
* 🧾 Optional `.txt` description file

Zero clutter left behind.

---

## Platform Notes

* **Windows**: fully supported (clipboard, hidden subprocesses)
* **Linux**: requires `xclip` for clipboard
* **macOS**: uses `pbcopy`

---

## Who This Is For

* TorrentBD uploaders
* Private tracker regulars
* Release groups

If you upload more than once a month, this pays for itself instantly.

---

## Author

**xnabil**
GitHub: [https://github.com/xNabil](https://github.com/xNabil)
