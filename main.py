import os
import sys
import shutil
import subprocess
import requests
import concurrent.futures
from pathlib import Path
from datetime import datetime
import tkinter as tk
from tkinter import filedialog
import random

# ========================= CONFIGURATION =========================
IMGBB_API_KEY = "YOUR IMGBB API KEY"   # CHANGE THIS! (Revoke the old one if exposed!)
FREEIMAGE_API_KEY = "6d207e02198a847aa98d0a2a901485a5"

IMAGE_HOST = "freeimage"               # "imgbb" or "freeimage"
                                       # imgbb → max file size 32 MB
                                       # freeimage → max file size 64 MB

SCREENSHOT_COUNT = 6
LOSSLESS_SCREENSHOT = True             # True = PNG (fallback to JPG if > max size of chosen host) | False = Always JPG
CREATE_TORRENT_FILE = True             # False = Skip .torrent creation
SKIP_TXT = False                        # True = Don't save .txt file (but still copy to clipboard)
TRACKER_ANNOUNCE = "https://tracker.torrentbd.net/announce"
PRIVATE_TORRENT = True
COPY_TO_CLIPBOARD = True
USE_WP_PROXY = False                   # True = Use https://i1.wp.com/ proxy | False = Direct link
USE_GUI_FILE_PICKER = False            # If False, use terminal to navigate and pick folders/files. Ideal for Linux.
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
    
    log("Creating torrent file...", "Torrent")
    out = target.parent / f"{target.name}.torrent"
    cmd = ["mkbrr", "create", "-t", TRACKER_ANNOUNCE,
           f"--private={'true' if PRIVATE_TORRENT else 'false'}", "-o", str(out), str(target)]
    
    process = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
        universal_newlines=True,
        startupinfo=hide_window()
    )
    
    while True:
        line = process.stdout.readline()
        if not line and process.poll() is not None:
            break
        if line:
            line = line.strip()
            if "Hashing pieces" in line or "%" in line or "Wrote" in line:
                print(f"\r{c.CYAN}{line}{c.RESET}", end="", flush=True)
    
    print()
    
    returncode = process.wait()
    
    if returncode == 0 and out.exists():
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

    # Determine max size based on selected host
    max_size_mb = 32 if IMAGE_HOST.lower() == "imgbb" else 64

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

            # Fallback to JPG if PNG exceeds host's max file size
            if LOSSLESS_SCREENSHOT and ext == "png" and size_mb > max_size_mb:
                output_file.unlink()
                jpeg_file = Path(f"ss_{i:02d}.jpg")
                cmd_jpg = ["ffmpeg", "-ss", f"{timestamp:.3f}", "-i", str(video),
                           "-vframes", "1", "-q:v", "1", "-y", str(jpeg_file)]
                subprocess.run(cmd_jpg, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, startupinfo=hide_window())
                if jpeg_file.exists():
                    files.append(jpeg_file)
                    print(f"   {c.YELLOW}Success {i}/{count} → JPEG (PNG too big: {size_mb:.1f}MB > {max_size_mb}MB limit){c.RESET}")
                continue

            files.append(output_file)
            fmt = "PNG" if ext == "png" else "JPG"
            print(f"   {c.GREEN}Success {i}/{count} → {fmt} ({size_mb:.1f} MB){c.RESET}")
        else:
            print(f"   {c.RED}Failed {i}/{count}{c.RESET}")

    return files

def upload_image(img: Path) -> str | None:
    try:
        if IMAGE_HOST.lower() == "imgbb":
            if IMGBB_API_KEY == "YOUR IMGBB API KEY":
                print(f"   {c.RED}imgbb API key not set!{c.RESET}")
                return None
            r = requests.post("https://api.imgbb.com/1/upload",
                              params={"key": IMGBB_API_KEY},
                              files={"image": open(img, "rb")}, timeout=60)
            if r.status_code == 200:
                return r.json()["data"]["url"]

        elif IMAGE_HOST.lower() == "freeimage":
            r = requests.post("https://freeimage.host/api/1/upload",
                              params={"key": FREEIMAGE_API_KEY},
                              files={"source": open(img, "rb")},  # freeimage.host uses "source"
                              data={"format": "json"}, timeout=60)
            if r.status_code == 200:
                data = r.json()
                if data.get("status_code") == 200:
                    return data["image"]["url"]

        print(f"   {c.RED}Upload failed for {img.name} ({IMAGE_HOST}){c.RESET}")
    except Exception as e:
        print(f"   {c.RED}Upload exception for {img.name}: {str(e)}{c.RESET}")
    return None

def print_progress(done: int, total: int):
    bar_length = 10
    filled = int(bar_length * done // total)
    bar = "█" * filled + "▒" * (bar_length - filled)
    print(f"\r{c.CYAN}Uploading {total} screenshots... [{bar}] {done}/{total} uploaded{c.RESET}", end="", flush=True)
    if done == total:
        print()

def gui_select_target() -> tuple[Path, bool]:
    root = tk.Tk()
    root.withdraw()
    root.update()
    while True:
        banner()
        print(f"{c.BOLD}{c.CYAN}Choose an option:{c.RESET}")
        print(f"  {c.WHITE}1{c.RESET} - Select a single video file")
        print(f"  {c.WHITE}2{c.RESET} - Select an entire folder (multi-episode/season)")
        print(f"  {c.GRAY}(q to quit){c.RESET}\n")
        choice = input(f"{c.BOLD}Enter 1 or 2: {c.RESET}").strip().lower()
        if choice == 'q':
            sys.exit(0)
        if choice == '1':
            file_path = filedialog.askopenfilename(
                title="Select a Video File",
                filetypes=[("Video Files", "*.mkv *.mp4 *.avi *.mov *.m4v *.webm *.flv *.wmv *.mpg *.mpeg *.ts *.m2ts")]
            )
            if file_path:
                return Path(file_path), False
        elif choice == '2':
            folder_path = filedialog.askdirectory(title="Select Folder Containing Videos")
            if folder_path:
                return Path(folder_path), True
        else:
            input(f"{c.RED}Invalid choice — press Enter to try again...{c.RESET}")

def cli_select_target() -> tuple[Path, bool]:
    current = Path.cwd().resolve()
    while True:
        banner()
        print(f"{c.BOLD}{c.CYAN}Current directory: {current}{c.RESET}")
        items = sorted([p for p in current.iterdir() if p.is_dir() or p.suffix.lower() in VIDEO_EXTS])
        if not items:
            print(f"{c.YELLOW}No folders or video files in this directory.{c.RESET}")
            choice = input(f"{c.BOLD}Enter 0 to go back or q to quit: {c.RESET}").strip().lower()
            if choice == '0' and current != Path.cwd().resolve():
                current = current.parent
                continue
            elif choice == 'q':
                sys.exit(0)
            else:
                continue
        for i, item in enumerate(items, 1):
            typ = f"{c.PURPLE}Dir{c.RESET}" if item.is_dir() else f"{c.CYAN}File{c.RESET}"
            print(f"  {c.WHITE}{i}{c.RESET}. {item.name} ({typ})")
        print(f"  {c.WHITE}0{c.RESET}. Go back" if current != Path.cwd().resolve() else f"  {c.WHITE}0{c.RESET}. Quit")
        choice = input(f"{c.BOLD}Enter number (or q to quit): {c.RESET}").strip().lower()
        if choice == 'q' or choice == '0':
            if choice == '0' and current == Path.cwd().resolve():
                sys.exit(0)
            elif choice == '0':
                current = current.parent
                continue
            else:
                sys.exit(0)
        try:
            num = int(choice)
            if 1 <= num <= len(items):
                selected = items[num - 1]
                if selected.is_dir():
                    sub_choice = input(f"{c.BOLD}Navigate into '{selected.name}' (n) or select as target folder (s)? {c.RESET}").strip().lower()
                    if sub_choice == 'n':
                        current = selected
                    elif sub_choice == 's':
                        return selected, True
                    else:
                        print(f"{c.RED}Invalid choice.{c.RESET}")
                else:
                    return selected, False
            else:
                print(f"{c.RED}Invalid number.{c.RESET}")
        except ValueError:
            print(f"{c.RED}Invalid input.{c.RESET}")

def select_target() -> tuple[Path, bool]:
    if USE_GUI_FILE_PICKER:
        return gui_select_target()
    else:
        return cli_select_target()

def main():
    target_path, is_folder = select_target()
    if not target_path or not target_path.exists():
        return

    clear(); banner()
    print(f"{c.BOLD}{c.PURPLE}Selected → {target_path.name}{c.RESET} {'(Folder Mode)' if is_folder else ''}\n")

    if not create_torrent(target_path):
        if CREATE_TORRENT_FILE:
            input("\nPress Enter to exit...")
            return

    if is_folder:
        video_files = [f for f in target_path.rglob('*') if f.is_file() and f.suffix.lower() in VIDEO_EXTS]
        if not video_files:
            error("No video files found in the folder or subfolders!")
            input("\nPress Enter to exit...")
            return
        video_for_ss = random.choice(video_files)
        success(f"Randomly selected for screenshots & mediainfo: {video_for_ss.name}")
    else:
        video_for_ss = target_path

    mediainfo_text = get_mediainfo(video_for_ss)
    screenshots = take_screenshots(video_for_ss, SCREENSHOT_COUNT)

    if not screenshots:
        error("No screenshots were taken!")
        input("\nPress Enter to exit...")
        return

    uploaded_direct_urls = []
    total = len(screenshots)
    print_progress(0, total)

    with concurrent.futures.ThreadPoolExecutor(max_workers=16) as executor:
        futures = {executor.submit(upload_image, img): img for img in screenshots}
        done_count = 0
        for future in concurrent.futures.as_completed(futures):
            result = future.result()
            if result:
                uploaded_direct_urls.append(result)
            done_count += 1
            print_progress(done_count, total)

    if not uploaded_direct_urls:
        error("All uploads failed!")
        input("\nPress Enter to exit...")
        return

    for f in Path(".").glob("ss_*.*"):
        try: f.unlink()
        except: pass

    ss_lines = []
    for direct_url in uploaded_direct_urls:
        if USE_WP_PROXY:
            proxy_url = "https://i1.wp.com/" + direct_url.split("://")[1]
            ss_lines.append(f"[img]{proxy_url}[/img]")
        else:
            ss_lines.append(f"[img]{direct_url}[/img]")

    ss_bbcode = "\n".join(ss_lines)

    description = f"""[hr]
[center][b][size=5][color=#00acc1]MediaInfo[/color][/size][/b][/center]
[hr]
[font=Times New Roman]
[mediainfo]
{mediainfo_text}
[/mediainfo]
[/font]
[hr]
[center][b][size=5][color=#00acc1]Screenshots[/color][/size][/b]
[size=2][color=#9e9e9e]Straight from the source - untouched frames.[/color][/size][/center]
[hr]
[center]
{ss_bbcode}
[/center]
[hr]"""

    if not SKIP_TXT:
        save_name = f"{target_path.name}_description.txt" if is_folder else f"{target_path.stem}_TBD_Description.txt"
        txt_file = target_path.parent / save_name
        txt_file.write_text(description, encoding="utf-8")
        success(f"Saved → {txt_file.name}")
    else:
        log("Skipping .txt save (SKIP_TXT = True)", "Skip")

    copy_to_clipboard(description)
    print(f"\n{c.BOLD}{c.GREEN}ALL DONE! Paste the description on TorrentBD now!{c.RESET}")
    input(f"\nPress Enter to exit...")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print(f"\n\n{c.YELLOW}Cancelled by user. Bye!{c.RESET}")
