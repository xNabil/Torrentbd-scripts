import os
import sys
import shutil
import subprocess
import requests
import base64
import concurrent.futures
from pathlib import Path
from datetime import datetime

# ========================= CONFIGURATION =========================
IMGBB_API_KEY = "ce3fef4a4f7e0380b85b4a415bd35d42"   # CHANGE THIS!
SCREENSHOT_COUNT = 3
LOSSLESS_SCREENSHOT = True         # True = PNG (fallback to JPG if >32MB) | False = Always JPG
CREATE_TORRENT_FILE = True         # False = Skip .torrent creation
SKIP_TXT = True                   # True = Don't save .txt file (but still copy to clipboard)
TRACKER_ANNOUNCE = "https://tracker.torrentbd.net/announce"
PRIVATE_TORRENT = True
COPY_TO_CLIPBOARD = True
# ================================================================

VIDEO_EXTS = {'.mkv', '.mp4', '.avi', '.mov', '.m4v', '.webm', '.flv', '.wmv', '.mpg', '.mpeg', '.ts', '.m2ts'}

class c:
    RESET   = '\033[0m'
    BOLD    = '\033[1m'
    DIM     = '\033[2m'
    PURPLE  = '\033[95m'
    CYAN    = '\033[96m'
    GREEN   = '\033[92m'
    YELLOW  = '\033[93m'
    RED     = '\033[91m'
    GRAY    = '\033[90m'
    WHITE   = '\033[97m'

def clear(): os.system('cls' if os.name == 'nt' else 'clear')

def banner():
    clear()
    print(f"""
{c.PURPLE}{c.BOLD}
╔══════════════════════════════════════════════════════════════════╗
║               Torrent Auto Description Maker                     ║
║             By xnabil (https://github.com/xNabil)                ║
╚══════════════════════════════════════════════════════════════════╝
{c.RESET}""")

def log(msg: str, icon: str = "•", color: str = c.CYAN):
    t = datetime.now().strftime("%H:%M:%S")
    print(f"{color}[{t}] {icon} {msg}{c.RESET}")

def success(msg): log(msg, "Success", c.GREEN)
def error(msg):   log(msg, "Error", c.RED)

def hide_window():
    if os.name == 'nt':
        si = subprocess.STARTUPINFO()
        si.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        si.wShowWindow = subprocess.SW_HIDE
        return si
    return None

def copy_to_clipboard(text: str):
    if not COPY_TO_CLIPBOARD: return
    try:
        if os.name == 'nt':
            subprocess.run('clip', input=text.encode('utf-8'), check=True)
        elif sys.platform == 'darwin':
            subprocess.run('pbcopy', input=text.encode('utf-8'), check=True)
        else:
            subprocess.run(['xclip', '-selection', 'clipboard'], input=text.encode('utf-8'), check=True)
        success("Description copied to clipboard!")
    except:
        pass

def create_torrent(target: Path) -> bool:
    if not CREATE_TORRENT_FILE:
        log("Skipping torrent creation (disabled)", "Skip")
        return True
    if not shutil.which("mkbrr"):
        error("mkbrr not found! → https://github.com/autobrr/mkbrr")
        return False
    out = target.parent / f"{target.name}.torrent"
    cmd = ["mkbrr", "create", "-t", TRACKER_ANNOUNCE,
           f"--private={'true' if PRIVATE_TORRENT else 'false'}", "-o", str(out), str(target)]
    r = subprocess.run(cmd, capture_output=True, text=True, startupinfo=hide_window())
    if r.returncode == 0 and out.exists():
        success(f"Torrent created: {out.name}")
        return True
    else:
        error("Torrent creation failed!")
        return False

def get_mediainfo(path: Path) -> str:
    cmd = ["mediainfo", str(path)]
    if not shutil.which("mediainfo"):
        exe = Path(__file__).parent / "MediaInfo.exe"
        if exe.exists():
            cmd = [str(exe), str(path)]
        else:
            error("MediaInfo not found!")
            return "MediaInfo not available"
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, startupinfo=hide_window(), timeout=120)
        return result.stdout if result.returncode == 0 else "Failed"
    except:
        return "Failed"

def take_screenshots(video: Path, count: int = SCREENSHOT_COUNT) -> list[Path]:
    log(f"Taking {count} full-size screenshots (20% → 80%)...", "Camera")
    try:
        duration = float(subprocess.check_output([
            "ffprobe", "-v", "error", "-show_entries", "format=duration",
            "-of", "default=noprint_wrappers=1:nokey=1", str(video)
        ], startupinfo=hide_window()).decode().strip())
    except:
        error("ffprobe not found! Install ffmpeg.")
        return []

    if duration <= 0:
        error("Invalid video duration.")
        return []

    start_percent = 0.20
    end_percent = 0.80
    total_range = end_percent - start_percent
    files = []

    for i in range(1, count + 1):
        progress = i / (count + 1)
        percent = start_percent + (total_range * progress)
        timestamp = duration * percent

        ext = "png" if LOSSLESS_SCREENSHOT else "jpg"
        output_file = Path(f"ss_{i:02d}.{ext}")

        cmd = ["ffmpeg", "-ss", f"{timestamp:.3f}", "-i", str(video),
               "-vframes", "1", "-q:v", "1", "-y", str(output_file)]

        subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, startupinfo=hide_window())

        if output_file.exists():
            size_mb = output_file.stat().st_size / (1024 * 1024)

            # Auto fallback if PNG > 32MB
            if LOSSLESS_SCREENSHOT and ext == "png" and size_mb > 32:
                output_file.unlink()
                jpeg_file = Path(f"ss_{i:02d}.jpg")
                cmd_jpg = ["ffmpeg", "-ss", f"{timestamp:.3f}", "-i", str(video),
                           "-vframes", "1", "-q:v", "1", "-y", str(jpeg_file)]
                subprocess.run(cmd_jpg, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, startupinfo=hide_window())
                if jpeg_file.exists():
                    files.append(jpeg_file)
                    print(f"   {c.YELLOW}Success {i}/{count} → JPEG (PNG too big: {size_mb:.1f}MB){c.RESET}")
                continue

            files.append(output_file)
            fmt = "PNG" if ext == "png" else "JPG"
            print(f"   {c.GREEN}Success {i}/{count} → {fmt} ({size_mb:.1f} MB){c.RESET}")
        else:
            print(f"   {c.RED}Failed {i}/{count}{c.RESET}")

    return files

def upload_imgbb(img: Path):
    try:
        with open(img, "rb") as f:
            b64 = base64.b64encode(f.read()).decode()
        r = requests.post("https://api.imgbb.com/1/upload",  # ← Fixed: was garbage text!
                          data={"key": IMGBB_API_KEY, "image": b64}, timeout=40)
        if r.status_code == 200:
            data = r.json()["data"]
            return {
                "viewer": data["url_viewer"],
                "img": data.get("medium", {}).get("url", data["url"])
            }
    except:
        pass
    return None

def print_progress(done: int, total: int):
    bar_length = 10
    filled = int(bar_length * done // total)
    bar = "█" * filled + "▒" * (bar_length - filled)
    print(f"\r{c.CYAN}Uploading {total} screenshots... [{bar}] {done}/{total} uploaded{c.RESET}", end="", flush=True)
    if done == total:
        print()  # New line

def file_browser() -> tuple[Path, bool]:
    cur = Path(".").resolve()
    while True:
        banner()
        print(f"{c.BOLD}{c.CYAN}Current Folder → {c.WHITE}{cur}{c.RESET}\n")
        
        folders = sorted([p for p in cur.iterdir() if p.is_dir()], key=lambda x: x.name.lower())
        files   = sorted([p for p in cur.iterdir() if p.is_file() and p.suffix.lower() in VIDEO_EXTS], key=lambda x: x.name.lower())
        
        entries = []
        if cur.parent != cur:
            entries.append(("..", "Parent folder", True))
        for f in folders:
            entries.append((f.name + "/", "", True))
        for f in files:
            size_gb = f.stat().st_size / (1024**3)
            entries.append((f.name, f"{size_gb:.2f} GB", False))

        for i, (name, info, is_dir) in enumerate(entries, 1):
            color = c.YELLOW if is_dir or name.endswith("/") else c.WHITE
            print(f"  {c.DIM}{i:2d}.{c.RESET} {color}{name:<50} {c.GRAY}{info}{c.RESET}")

        try:
            choice = input(f"\n{c.BOLD}Select (1-{len(entries)}) or q to quit: {c.RESET}").strip()
            if choice.lower() == 'q': sys.exit(0)
            idx = int(choice) - 1
            selected_path = (cur / entries[idx][0].rstrip("/")).resolve()
            if selected_path.is_dir():
                if entries[idx][0] == "..":
                    cur = cur.parent
                else:
                    cur = selected_path
            else:
                return selected_path, False
        except:
            input(f"{c.RED}Invalid input — press Enter...{c.RESET}")

        ans = input(f"\n{c.CYAN}Upload ENTIRE folder? (yes or Enter): {c.RESET}").strip().lower()
        if ans in ['yes', 'y', '']:
            video_files = [f for f in cur.iterdir() if f.suffix.lower() in VIDEO_EXTS]
            if not video_files:
                error("No video files found!"); input(); continue
            return cur, True

def main():
    target_path, is_folder = file_browser()
    if not target_path: return

    clear(); banner()
    print(f"{c.BOLD}{c.PURPLE}Selected → {target_path.name}{c.RESET} {'(Folder Mode)' if is_folder else ''}\n")

    if is_folder:
        video_files = [f for f in target_path.iterdir() if f.suffix.lower() in VIDEO_EXTS]
        video_for_ss = max(video_files, key=lambda x: x.stat().st_size)
        success(f"Using for screenshots: {video_for_ss.name}")
    else:
        video_for_ss = target_path

    if not create_torrent(target_path):
        if CREATE_TORRENT_FILE:
            input("\nPress Enter to exit..."); return

    mediainfo_text = get_mediainfo(video_for_ss)
    screenshots = take_screenshots(video_for_ss, SCREENSHOT_COUNT)

    # === UPLOAD WITH PROGRESS BAR ===
    uploaded = []
    total = len(screenshots)
    print_progress(0, total)

    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as executor:
        future_to_idx = {executor.submit(upload_imgbb, img): i for i, img in enumerate(screenshots)}
        done_count = 0
        for future in concurrent.futures.as_completed(future_to_idx):
            result = future.result()
            if result:
                uploaded.append(result)
            done_count += 1
            print_progress(done_count, total)

    # Cleanup
    for f in Path(".").glob("ss_*.*"):
        try: f.unlink()
        except: pass

    ss_bbcode = "\n".join(f"[url={u['viewer']}][img]{u['img']}[/img][/url]" for u in uploaded)

    description = f"""[center][url=https://imgbb.com/][img]https://i.ibb.co.com/35XrJ9P0/Syacm.gif[/img][/url][/center]

[hr]
[center][b][color=#00acc1][size=6][font=Comic Sans MS]Mediainfo[/font][/size][/color][/b][/center]
[hr]

[font=Times New Roman]
[mediainfo]
{mediainfo_text}
[/mediainfo]
[/font]

[hr]
[center][b][color=#00acc1][size=6][font=Comic Sans MS]Screenshots[/font][/size][/color][/b][/center]
[hr]

{ss_bbcode}

[hr]"""

    if not SKIP_TXT:
        save_name = f"{target_path.name}_TBD_Description.txt" if is_folder else f"{target_path.stem}_TBD_Description.txt"
        txt_file = target_path.parent / save_name
        txt_file.write_text(description, encoding="utf-8")
        success(f"Saved → {txt_file.name}")
    else:
        log("Skipping .txt save (SKIP_TXT = True)", "Skip")

    copy_to_clipboard(description)
    print(f"\n{c.BOLD}{c.GREEN}ALL DONE! Paste on TorrentBD now!{c.RESET}")
    input(f"\nPress Enter to exit...")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print(f"\n\n{c.YELLOW}Cancelled by user. Bye!{c.RESET}")
