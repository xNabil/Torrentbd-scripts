# Torrent Auto Description Maker

A powerful Python automation tool designed for uploaders on private trackers (optimized for **TorrentBD**). This script streamlines the release process by automatically creating torrent files, generating media info, taking screenshots, uploading them to ImgBB, and formatting a stylish BBCode description.

## 🚀 Features

* **Automatic Torrent Creation:** Uses `mkbrr` to create private `.torrent` files with the correct announce URL.
* **Smart Screenshots:**
    * Automatically captures 6 screenshots spread evenly between 20% and 80% of the video duration.
    * **Lossless Logic:** Attempts PNG first; falls back to JPG if the file size exceeds 32MB.
* **MediaInfo Extraction:** Scans video files and generates clean MediaInfo text.
* **Image Hosting:** Automatically uploads screenshots to **ImgBB** via API.
* **Folder Support:**
    * **Single File:** Processes a single movie/video.
    * **Folder Mode:** Detects TV seasons/packs, creates a torrent for the whole folder, and selects a random video for the sample screenshots.
* **Clipboard Ready:** Automatically copies the final BBCode description to your clipboard.

## 🛠 Prerequisites

To run this tool, you need **Python 3.x** and the following external tools installed and added to your system PATH.

### 1. System Tools
* **FFmpeg:** Required for taking screenshots. [Download Here](https://ffmpeg.org/download.html)
* **MediaInfo:** Required for scanning metadata. [Download Here](https://mediaarea.net/en/MediaInfo)
* **mkbrr:** Required for creating torrent files. [Download Here](https://github.com/autobrr/mkbrr)

### 2. Python Libraries
Install the required Python dependency:

```bash
pip install requests
````

*(Note: `tkinter` is usually included with Python, but Linux users might need to install `python3-tk`)*.

-----

## ⚙️ Configuration

**Before running the script, you must configure your API key.**

1.  Open the script file in a text editor.
2.  Locate the `CONFIGURATION` block at the top.
3.  Replace `"YOUR IMGBB API KEY"` with your actual key.

> **Get your free API Key here:** [https://api.imgbb.com/](https://api.imgbb.com/)

```python
# ========================= CONFIGURATION =========================
IMGBB_API_KEY = "YOUR IMGBB API KEY"   # CHANGE THIS! (Revoke the old one!)
SCREENSHOT_COUNT = 6
LOSSLESS_SCREENSHOT = True         # True = PNG (fallback to JPG if >32MB) | False = Always JPG
CREATE_TORRENT_FILE = True         # False = Skip .torrent creation
SKIP_TXT = True                   # True = Don't save .txt file (but still copy to clipboard)
TRACKER_ANNOUNCE = "https://tracker.torrentbd.net/announce"
PRIVATE_TORRENT = True
COPY_TO_CLIPBOARD = True
USE_WP_PROXY = False               # True = Use https://i1.wp.com/ proxy | False = Direct link
# ================================================================
```

-----

## 🖥️ Usage

1.  Run the script via your terminal or command prompt:

    ```bash
    python main.py
    ```

2.  A menu will appear asking for your input mode:

      * **Option 1:** Select a single video file (e.g., `.mkv`, `.mp4`).
      * **Option 2:** Select a folder (useful for Season Packs).

3.  **The Process:**

      * The script creates the `.torrent` file in the same directory as your media.
      * It generates screenshots and MediaInfo.
      * It uploads images to ImgBB.
      * It generates the BBCode description.

4.  **Finish:**

      * The BBCode is copied to your **clipboard**.
      * A `.txt` file containing the description is saved alongside your media (optional).
      * Paste the clipboard content directly into the TorrentBD upload page.

-----

## 📂 Supported Formats

The script supports the following video extensions:
`.mkv`, `.mp4`, `.avi`, `.mov`, `.m4v`, `.webm`, `.flv`, `.wmv`, `.mpg`, `.mpeg`, `.ts`, `.m2ts`

## 📝 License

This project is open-source. Feel free to modify it to suit your needs.

-----

*Created by xNabil*


***

### Next Steps for You

1.  **Dependencies:** Ensure you have `ffmpeg`, `mediainfo`, and `mkbrr` installed and added to your System Environment Variables (PATH), otherwise the script will throw errors.
2.  **API Key:** Don't forget to get a fresh API key from ImgBB, as the placeholder in the code won't work.

**Would you like me to create a `requirements.txt` file specifically for this project as well?**
