import os
import subprocess
import requests
import glob
import json
import io
import shutil
import concurrent.futures
import base64
from pathlib import Path

# ImgBB API Configuration
IMGBB_API = "https://api.imgbb.com/1/upload"
IMGBB_API_KEY = "XXXXXXXXXXXXXXXX" # <- Put your ImgBB API key here
SCREENSHOT_COUNT = 4  # Number of screenshots to upload

from datetime import datetime

# Helper function for Windows console hiding
def get_startupinfo():
   if os.name == 'nt':
       startupinfo = subprocess.STARTUPINFO()
       startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
       return startupinfo
   return None

#Logging System
def log(level, message):
   timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-2]
   print(f"{timestamp}|{level}|{message}")

def log_info(message):
   log("INFO", message)

def log_warn(message):
   log("WARN", message)

def log_error(message):
   log("ERROR", message)


# Function to select MKV file from last 5 added
def select_mkv_file():
   mkv_files = glob.glob("*.mkv")
   if not mkv_files:
       log_error("No MKV files found.")
       return None
   # Sort by creation time, newest first
   mkv_files.sort(key=os.path.getctime, reverse=True)
   top_files = mkv_files[:5]
   log_info("Select an MKV file to process:")
   for idx, fname in enumerate(top_files, 1):
       ctime = datetime.fromtimestamp(os.path.getctime(fname)).strftime("%Y-%m-%d %H:%M:%S")
       print(f"  {idx}. {fname} (added: {ctime})")
   while True:
       try:
           choice = input(f"Enter a number (1-{len(top_files)}) to select file: ").strip()
           if not choice.isdigit():
               log_warn("Please enter a valid number.")
               continue
           choice = int(choice)
           if 1 <= choice <= len(top_files):
               return top_files[choice-1]
           else:
               log_warn(f"Please enter a number between 1 and {len(top_files)}.")
       except (KeyboardInterrupt, EOFError):
           log_error("Selection cancelled by user.")
           return None


# Mkbrr - based torrent creation---
def create_torrent(input_path):
   if not shutil.which("mkbrr"):
       log_error("mkbrr not found in PATH. Install from: https://github.com/autobrr/mkbrr")
       return None
   input_path = Path(input_path)
   if input_path.is_file():
       torrent_name = input_path.stem + ".torrent"
       torrent_path = input_path.parent / torrent_name
   elif input_path.is_dir():
       torrent_name = input_path.name + ".torrent"
       torrent_path = input_path.parent / torrent_name
   else:
       log_error(f"Path does not exist: {input_path}")
       return None
   cmd = [
       "mkbrr", "create",
       "-t", "https://tracker.torrentbd.net/announce",
       "--private=true",
       "-o", str(torrent_path),
       str(input_path)
   ]
   startupinfo = None
   if os.name == 'nt':
       startupinfo = subprocess.STARTUPINFO()
       startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
       startupinfo.wShowWindow = subprocess.SW_HIDE
   result = subprocess.run(cmd, capture_output=True, text=True, startupinfo=startupinfo, timeout=300)
   if result.returncode == 0 and os.path.exists(torrent_path):
       log_info(f"✅ .torrent file saved as: {torrent_path}")
       return str(torrent_path)
   else:
       log_error(f"❌ mkbrr failed: {result.stderr.strip()}")
       return None


#MediaInfo extraction
def get_mediainfo(file_path):
   mediainfo_path = "mediainfo"
   if os.name == 'nt' and not shutil.which("mediainfo"):
       mediainfo_path = "MediaInfo.exe"
   try:
       result = subprocess.run([mediainfo_path, file_path], capture_output=True, text=True, timeout=60)
       if result.returncode == 0:
           return result.stdout.strip()
       else:
           return f"Error: MediaInfo failed ({result.stderr.strip()})"
   except Exception as e:
       return f"Error: {e}"


#Screenshot logic
def get_video_duration(video_path):
   duration_cmd = ["ffprobe", "-v", "quiet", "-show_entries", "format=duration", "-of", "csv=p=0", video_path]
   result = subprocess.run(duration_cmd, capture_output=True, text=True)
   if result.returncode != 0:
       return None
   try:
       return float(result.stdout.strip())
   except Exception:
       return None

def take_screenshots_to_disk(video_path, count=4):
   duration_cmd = ['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'default=noprint_wrappers=1:nokey=1', video_path]
   duration_output = subprocess.run(duration_cmd, capture_output=True, text=True, startupinfo=get_startupinfo())
   duration = float(duration_output.stdout.strip())
   
   percentages = [20, 40, 60, 80] if count == 4 else [int(100 / (count + 1) * (i + 1)) for i in range(count)]
   
   screenshot_files = []
   for idx, pct in enumerate(percentages, 1):
       timestamp = duration * (pct / 100.0)
       screenshot_path = f"screenshot{idx}.jpg"
       
       # Use -ss before -i for fast seeking
       ffmpeg_cmd = [
           'ffmpeg', '-ss', str(timestamp), '-i', video_path,
           '-vframes', '1', '-q:v', '2', '-y', screenshot_path
       ]
       
       result = subprocess.run(ffmpeg_cmd, capture_output=True, startupinfo=get_startupinfo())
       if result.returncode == 0 and os.path.exists(screenshot_path):
           screenshot_files.append(screenshot_path)
       else:
           screenshot_files.append(None)
   
   successful = len([f for f in screenshot_files if f])
   log_info(f"{successful}/{count} screenshots saved.")
   return screenshot_files

def upload_to_imgbb(image_path, api_key=IMGBB_API_KEY):
   if not image_path or not os.path.exists(image_path):
       return None
   
   try:
       with open(image_path, 'rb') as f:
           image_b64 = base64.b64encode(f.read()).decode('utf-8')
       
       payload = {'key': api_key, 'image': image_b64}
       response = requests.post("https://api.imgbb.com/1/upload",  data=payload, timeout=60)
       response.raise_for_status()
       data = response.json()
       
       if data.get("success"):
           url_viewer = data['data']['url_viewer']
           # Use medium URL if available, otherwise fall back to url
           medium_url = data['data'].get('medium', {}).get('url')
           img_url = medium_url if medium_url else data['data']['url']
           
           return {
               'viewer': url_viewer,
               'img': img_url
           }
   except Exception as e:
       log_error(f"ImgBB upload failed: {e}")
   return None

def take_and_upload_screenshots(video_path, count=4):
   screenshot_files = take_screenshots_to_disk(video_path, count)
   screenshots_urls = [None] * count
   
   def upload_worker(idx, screenshot_path):
       if screenshot_path:
           url_info = upload_to_imgbb(screenshot_path)
           if url_info:
               screenshots_urls[idx] = url_info
               log_info(f"✅ Screenshot {idx+1} uploaded!")
   
   # Upload all screenshots
   log_info("Uploading all screenshots...")
   with concurrent.futures.ThreadPoolExecutor(max_workers=count) as executor:
       futures = [executor.submit(upload_worker, idx, path) for idx, path in enumerate(screenshot_files)]
       concurrent.futures.wait(futures)
   
   # Cleanup temporary screenshot files
   for screenshot_path in screenshot_files:
       if screenshot_path and os.path.exists(screenshot_path):
           try:
               os.remove(screenshot_path)
           except Exception as e:
               log_warn(f"Failed to delete {screenshot_path}: {e}")
   
   return screenshots_urls

# Function to process the selected MKV file
def process_selected_mkv():
   selected_mkv = select_mkv_file()

   if not selected_mkv:
       return

   log_info(f"Processing: {selected_mkv}")

   # Step 1: Create Torrent
   log_info("Creating torrent...")
   torrent_file = create_torrent(selected_mkv)
   if not torrent_file:
       log_error(f"Skipping processing as torrent creation failed for {selected_mkv}.")
       return
   log_info("Extracting MediaInfo...")

   media_info = get_mediainfo(selected_mkv)
   log_info("MediaInfo extracted & saved...")
   log_info("Taking and uploading screenshots...")
   # Step 3: Take and upload 4 screenshots at 20%, 40%, 60%, 80%
   screenshot_infos = take_and_upload_screenshots(selected_mkv, count=SCREENSHOT_COUNT)

   log_info("Structuring output...")
   # Step 4: Structure output with proper BBCode formatting
   output = f"Full media info text required.\n"

   if screenshot_infos:
       formatted_links = "\n".join(
           f"[url={item['viewer']}][img]{item['img']}[/img][/url]" for item in screenshot_infos if item and 'viewer' in item and 'img' in item
       )
       output += f"{formatted_links} "

   # Step 5: Save description to file
   desc_filename = "tbd.txt"
   with open(desc_filename, "w") as desc_file:
       desc_file.write(output)

   log_info(f"Saved Complete description to {desc_filename}")

# Run script
if __name__ == "__main__":
   process_selected_mkv()
