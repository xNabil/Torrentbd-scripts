# Torrent Auto Description Maker

A powerful Python CLI tool designed to automate the creation of torrent descriptions for private trackers (specifically configured for **TorrentBD**). It handles everything from creating the `.torrent` file to generating Mediainfo, taking screenshots, uploading them to ImgBB, and formatting the final description in BBCode.

## 🚀 Features

* **Automated Torrent Creation:** Uses `mkbrr` to generate private torrent files automatically.
* **Smart Screenshots:** * Automatically takes screenshots at evenly distributed timestamps (20% to 80% of video duration).
    * **Lossless Mode:** Attempts to save as PNG. Automatically falls back to JPG if the file size exceeds 32MB.
* **Auto-Upload:** Uploads screenshots directly to [ImgBB](https://imgbb.com/) via API.
* **MediaInfo Extraction:** Scans video files and generates a clean MediaInfo report.
* **BBCode Generation:** meaningful formatting (Center, Fonts, Colors) ready for tracker submission.
* **Clipboard Integration:** Automatically copies the final output to your clipboard.
* **Directory & File Support:** Works with single video files or entire Season packs/Folders.

## 🛠️ Prerequisites

To run this tool, you need the following installed on your system:

1.  **Python 3.x**
2.  **FFmpeg & FFprobe:** Required for taking screenshots.
    * *Windows:* [Download Build](https://gyan.dev/ffmpeg/builds/) and add to System PATH.
    * *Linux:* `sudo apt install ffmpeg`
3.  **MediaInfo:**
    * *Windows:* Install CLI or GUI version, or place `MediaInfo.exe` in the script folder.
    * *Linux:* `sudo apt install mediainfo`
4.  **mkbrr (Optional but Recommended):** Required for creating the `.torrent` file.
    * [Download mkbrr](https://github.com/autobrr/mkbrr) and add to System PATH.

## 📦 Installation

1.  **Clone the repository (or download the script):**
    ```bash
    git clone [https://github.com/yourusername/torrent-description-maker.git](https://github.com/yourusername/torrent-description-maker.git)
    cd torrent-description-maker
    ```

2.  **Install Python Dependencies:**
    ```bash
    pip install requests
    ```

## ⚙️ Configuration

Open the script file (e.g., `main.py`) in a text editor and look for the **CONFIGURATION** section at the top.

**You must set your ImgBB API Key:**

1.  Go to [api.imgbb.com](https://api.imgbb.com/).
2.  Get your free API Key.
3.  Replace the value in the script:

```python
# ========================= CONFIGURATION =========================
IMGBB_API_KEY = "YOUR_API_KEY_HERE"   # <--- PASTE KEY HERE
SCREENSHOT_COUNT = 3                  # Number of screenshots to take
LOSSLESS_SCREENSHOT = True            # True = PNG, False = JPG
CREATE_TORRENT_FILE = True            # Set to False if you don't use mkbrr
SKIP_TXT = True                       # True = Copy to clipboard only, don't save .txt
# ================================================================
````

## 🖥️ Usage

1.  Run the script:
    ```bash
    python main.py
    ```
2.  **File Browser:** The CLI will show a list of files and folders in the current directory.
      * Type the **number** of the file/folder you want to process.
      * Type `..` to go up a directory.
3.  **Folder Mode:** If you select a folder, it will ask if you want to upload the entire folder. Type `y` or press Enter.
4.  **Process:**
      * The script will generate the `.torrent` file.
      * It will scan for `MediaInfo`.
      * It will take screenshots and upload them.
5.  **Finish:** \* The BBCode description is automatically copied to your clipboard.
      * Paste it directly into the "Description" field on the upload page.

## 📝 output Example

The tool generates BBCode formatted like this:

```bbcode
[center][img][https://i.ibb.co/banner.gif](https://i.ibb.co/banner.gif)[/img][/center]
[hr]
[center][b][color=#00acc1][size=6]Mediainfo[/size][/color][/b][/center]
[hr]
[mediainfo]
...Video/Audio specs...
[/mediainfo]
[hr]
[center][b][color=#00acc1][size=6]Screenshots[/size][/color][/b][/center]
[hr]
[url=ViewerLink][img]DirectLink[/img][/url]
[url=ViewerLink][img]DirectLink[/img][/url]
```

## ⚠️ Troubleshooting

  * **"mkbrr not found":** Ensure `mkbrr` is in your Windows System Environment Variables (PATH), or set `CREATE_TORRENT_FILE = False` in the config.
  * **"ffprobe not found":** Ensure FFmpeg is installed and added to PATH.
  * **Upload Errors:** Check if your ImgBB API key is valid.

## 📄 License

Project created by [xNabil](https://github.com/xNabil).
