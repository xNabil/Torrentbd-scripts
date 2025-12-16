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

## Requirements

You’ll need these installed and available in `PATH`:

* **Python 3.9+**
* **ffmpeg** (includes `ffprobe`)
* **MediaInfo**
* **mkbrr** (for torrent creation)

  * [https://github.com/autobrr/mkbrr](https://github.com/autobrr/mkbrr)

Python dependencies:

```bash
pip install requests
```

> On Windows, `MediaInfo.exe` can live next to the script if it’s not in PATH.

---

## Configuration (Read This)

At the top of the script:

```python
IMGBB_API_KEY = "YOUR IMGBB API KEY"
FREEIMAGE_API_KEY = "your_freeimage_key"

IMAGE_HOST = "freeimage"   # "imgbb" or "freeimage"
SCREENSHOT_COUNT = 6
LOSSLESS_SCREENSHOT = True
CREATE_TORRENT_FILE = True
SKIP_TXT = True
TRACKER_ANNOUNCE = "https://tracker.torrentbd.net/announce"
PRIVATE_TORRENT = True
COPY_TO_CLIPBOARD = True
USE_WP_PROXY = False
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
