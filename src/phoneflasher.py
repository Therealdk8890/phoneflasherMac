import os
import queue
import subprocess
import threading
import time
import urllib.request
import zipfile
from pathlib import Path
import sys
import tkinter as tk
from tkinter import filedialog, messagebox, ttk
from tkinter.scrolledtext import ScrolledText

APP_NAME = "PhoneFlasher Mac"
APP_AUTHOR = "Daniel Kissel"

BASE_DIR = Path(__file__).resolve().parent
TOOLS_DIR = BASE_DIR / "tools"
VENDOR_DIR = BASE_DIR / "vendor"
DOWNLOADS_DIR = BASE_DIR / "downloads"

PLATFORM_TOOLS_URL = "https://dl.google.com/android/repository/platform-tools-latest-darwin.zip"
PLATFORM_TOOLS_ZIP = DOWNLOADS_DIR / "platform-tools-latest-darwin.zip"

VENDOR_TOOLS = {
    "Samsung Smart Switch (optional)": {
        "type": "dmg",
        "urls": [
            "https://downloadcenter.samsung.com/content/SW/201702/20170201105409656/SmartSwitch4Mac.dmg",
        ],
        "fallback_url": "https://www.samsung.com/us/support/owners/app/smart-switch",
    },
    "LG Bridge (optional)": {
        "type": "dmg",
        "urls": [
            "https://lgbridge-file.lge.com/LGBridge_1.2.0.dmg",
        ],
        "fallback_url": "https://www.lg.com/us/support/help-library/lg-bridge-downloads-20150771211485",
    },
    "OnePlus Support (optional)": {
        "type": "url",
        "urls": [],
        "fallback_url": "https://www.oneplus.com/support/softwareupgrade",
    },
    "Google Pixel (no driver required)": {
        "type": "url",
        "urls": [],
        "fallback_url": "https://developers.google.com/android/images",
    },
}


def ensure_dirs():
    for path in (TOOLS_DIR, VENDOR_DIR, DOWNLOADS_DIR):
        path.mkdir(parents=True, exist_ok=True)


def platform_tools_paths():
    adb = TOOLS_DIR / "platform-tools" / "adb"
    fastboot = TOOLS_DIR / "platform-tools" / "fastboot"
    return adb, fastboot


def is_macos():
    return sys.platform == "darwin"


def open_path(path):
    try:
        subprocess.run(["open", path], check=False)
    except Exception:
        return False
    return True


def open_url(url):
    try:
        subprocess.run(["open", url], check=False)
    except Exception:
        return False
    return True


class PhoneFlasherApp(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title(f"{APP_NAME} - {APP_AUTHOR}")
        self.geometry("980x720")
        self.resizable(True, True)

        self.log_queue = queue.Queue()
        self._build_ui()
        self._start_log_pump()

    def _build_ui(self):
        header = ttk.Frame(self)
        header.pack(fill=tk.X, padx=12, pady=(12, 0))

        title = ttk.Label(header, text=APP_NAME, font=("Helvetica", 18, "bold"))
        author = ttk.Label(header, text=f"by {APP_AUTHOR}", font=("Helvetica", 10))
        subtitle = ttk.Label(
            header,
            text="ADB/Fastboot flasher for Samsung, Pixel, LG, and OnePlus",
            font=("Helvetica", 10),
        )
        title.pack(anchor="w")
        author.pack(anchor="w")
        subtitle.pack(anchor="w")

        notebook = ttk.Notebook(self)
        notebook.pack(fill=tk.BOTH, expand=True, padx=12, pady=12)

        self.setup_tab = ttk.Frame(notebook)
        self.flash_tab = ttk.Frame(notebook)
        self.log_tab = ttk.Frame(notebook)

        notebook.add(self.setup_tab, text="Setup")
        notebook.add(self.flash_tab, text="Flash")
        notebook.add(self.log_tab, text="Logs")

        self._build_setup_tab()
        self._build_flash_tab()
        self._build_log_tab()

    def _build_setup_tab(self):
        tools_frame = ttk.LabelFrame(self.setup_tab, text="Platform Tools")
        tools_frame.pack(fill=tk.X, padx=8, pady=8)

        ttk.Label(
            tools_frame,
            text="Download and extract ADB/Fastboot to the local tools folder.",
        ).pack(anchor="w", padx=8, pady=(8, 4))

        tools_buttons = ttk.Frame(tools_frame)
        tools_buttons.pack(anchor="w", padx=8, pady=(0, 8))

        ttk.Button(
            tools_buttons, text="Download Platform Tools", command=self.download_platform_tools
        ).pack(side=tk.LEFT, padx=(0, 8))
        ttk.Button(
            tools_buttons, text="Open Tools Folder", command=lambda: self._open_folder(TOOLS_DIR)
        ).pack(side=tk.LEFT)

        vendor_frame = ttk.LabelFrame(self.setup_tab, text="Vendor Tools (Optional)")
        vendor_frame.pack(fill=tk.BOTH, expand=True, padx=8, pady=8)

        ttk.Label(
            vendor_frame,
            text="macOS does not require USB drivers for ADB/Fastboot. Vendor tools are optional.",
            wraplength=820,
        ).pack(anchor="w", padx=8, pady=(8, 4))

        ttk.Button(
            vendor_frame, text="Download All Vendor Tools", command=self.download_all_vendor_tools
        ).pack(anchor="w", padx=8, pady=(0, 8))

        for tool_name in VENDOR_TOOLS:
            row = ttk.Frame(vendor_frame)
            row.pack(fill=tk.X, padx=8, pady=6)

            ttk.Label(row, text=tool_name, width=32).pack(side=tk.LEFT)
            ttk.Button(
                row,
                text="Download",
                command=lambda name=tool_name: self.download_vendor_tool(name),
            ).pack(side=tk.LEFT, padx=(0, 8))
            ttk.Button(
                row,
                text="Open Folder",
                command=lambda name=tool_name: self._open_vendor_folder(name),
            ).pack(side=tk.LEFT, padx=(0, 8))
            ttk.Button(
                row,
                text="Open Vendor Page",
                command=lambda name=tool_name: self._open_vendor_page(name),
            ).pack(side=tk.LEFT)

    def _build_flash_tab(self):
        device_frame = ttk.LabelFrame(self.flash_tab, text="Device Status")
        device_frame.pack(fill=tk.X, padx=8, pady=8)

        buttons = ttk.Frame(device_frame)
        buttons.pack(anchor="w", padx=8, pady=(8, 4))

        ttk.Button(buttons, text="Refresh Devices", command=self.refresh_devices).pack(
            side=tk.LEFT, padx=(0, 8)
        )
        ttk.Button(buttons, text="Reboot to Bootloader", command=self.reboot_bootloader).pack(
            side=tk.LEFT, padx=(0, 8)
        )
        ttk.Button(buttons, text="Reboot to System", command=self.reboot_system).pack(
            side=tk.LEFT, padx=(0, 8)
        )
        ttk.Button(buttons, text="Fastboot Reboot", command=self.fastboot_reboot).pack(
            side=tk.LEFT
        )

        status_frame = ttk.Frame(device_frame)
        status_frame.pack(fill=tk.X, padx=8, pady=(0, 8))

        ttk.Label(status_frame, text="ADB:").grid(row=0, column=0, sticky="w")
        ttk.Label(status_frame, text="Fastboot:").grid(row=1, column=0, sticky="w")

        self.adb_status = ttk.Label(status_frame, text="Not checked")
        self.fastboot_status = ttk.Label(status_frame, text="Not checked")

        self.adb_status.grid(row=0, column=1, sticky="w", padx=(8, 0))
        self.fastboot_status.grid(row=1, column=1, sticky="w", padx=(8, 0))

        flash_frame = ttk.LabelFrame(self.flash_tab, text="Flash Images")
        flash_frame.pack(fill=tk.BOTH, expand=True, padx=8, pady=8)

        ttk.Label(
            flash_frame,
            text="Select image files to flash with fastboot. Only selected slots will be flashed.",
            wraplength=820,
        ).pack(anchor="w", padx=8, pady=(8, 4))

        self.flash_entries = {}
        for label, key in (
            ("Boot image", "boot"),
            ("Recovery image", "recovery"),
            ("System image", "system"),
            ("Vendor image", "vendor"),
        ):
            row = ttk.Frame(flash_frame)
            row.pack(fill=tk.X, padx=8, pady=4)

            ttk.Label(row, text=label, width=14).pack(side=tk.LEFT)
            entry = ttk.Entry(row)
            entry.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(0, 8))
            ttk.Button(
                row,
                text="Browse",
                command=lambda e=entry: self._browse_file(e),
            ).pack(side=tk.LEFT)
            self.flash_entries[key] = entry

        action_row = ttk.Frame(flash_frame)
        action_row.pack(anchor="w", padx=8, pady=8)

        ttk.Button(action_row, text="Flash Selected", command=self.flash_selected).pack(
            side=tk.LEFT, padx=(0, 8)
        )
        ttk.Button(action_row, text="Wipe Data", command=self.fastboot_wipe).pack(
            side=tk.LEFT
        )

        ttk.Label(
            flash_frame,
            text="Warning: Flashing can brick your device. Always use brand-specific firmware.",
            foreground="#b54b00",
        ).pack(anchor="w", padx=8, pady=(0, 8))

    def _build_log_tab(self):
        self.log_output = ScrolledText(self.log_tab, height=18)
        self.log_output.pack(fill=tk.BOTH, expand=True, padx=8, pady=8)
        self.log_output.configure(state="disabled")

    def _start_log_pump(self):
        self.after(100, self._flush_log)

    def _flush_log(self):
        while True:
            try:
                message = self.log_queue.get_nowait()
            except queue.Empty:
                break
            self.log_output.configure(state="normal")
            timestamp = time.strftime("%H:%M:%S")
            self.log_output.insert(tk.END, f"[{timestamp}] {message}\n")
            self.log_output.see(tk.END)
            self.log_output.configure(state="disabled")
        self.after(100, self._flush_log)

    def log(self, message):
        self.log_queue.put(message)

    def _run_in_thread(self, target, *args):
        thread = threading.Thread(target=target, args=args, daemon=True)
        thread.start()

    def _open_folder(self, path):
        if not open_path(str(path)):
            messagebox.showerror(APP_NAME, "Failed to open folder.")

    def _open_vendor_page(self, tool_name):
        url = VENDOR_TOOLS[tool_name]["fallback_url"]
        if not open_url(url):
            messagebox.showerror(APP_NAME, "Failed to open vendor page.")

    def _open_vendor_folder(self, tool_name):
        vendor_dir = VENDOR_DIR / tool_name.replace(" ", "_").lower()
        vendor_dir.mkdir(parents=True, exist_ok=True)
        self._open_folder(vendor_dir)

    def _browse_file(self, entry):
        file_path = filedialog.askopenfilename(
            title="Select image",
            filetypes=[("Image files", "*.img"), ("All files", "*.*")],
        )
        if file_path:
            entry.delete(0, tk.END)
            entry.insert(0, file_path)

    def download_platform_tools(self):
        self._run_in_thread(self._download_platform_tools)

    def _download_platform_tools(self):
        ensure_dirs()
        self.log("Downloading platform-tools...")
        success = self._download_first_available([PLATFORM_TOOLS_URL], PLATFORM_TOOLS_ZIP)
        if not success:
            self.log("Failed to download platform-tools.")
            return
        self.log("Extracting platform-tools...")
        try:
            with zipfile.ZipFile(PLATFORM_TOOLS_ZIP, "r") as zip_ref:
                zip_ref.extractall(TOOLS_DIR)
        except zipfile.BadZipFile:
            self.log("Downloaded platform-tools zip is corrupted.")
            return
        self._ensure_executable()
        self.log("Platform-tools extracted.")

    def download_all_vendor_tools(self):
        self._run_in_thread(self._download_all_vendor_tools)

    def _download_all_vendor_tools(self):
        for tool_name in VENDOR_TOOLS:
            self.log(f"Downloading {tool_name}...")
            self._download_vendor_tool(tool_name)

    def download_vendor_tool(self, tool_name):
        self._run_in_thread(self._download_vendor_tool, tool_name)

    def _download_vendor_tool(self, tool_name):
        ensure_dirs()
        info = VENDOR_TOOLS[tool_name]
        vendor_dir = VENDOR_DIR / tool_name.replace(" ", "_").lower()
        vendor_dir.mkdir(parents=True, exist_ok=True)

        if not info["urls"]:
            self.log(f"No direct download for {tool_name}. Opening vendor page.")
            self._open_vendor_page(tool_name)
            return

        ext = ".dmg" if info["type"] == "dmg" else ".pkg"
        dest = vendor_dir / f"{tool_name.replace(' ', '_').lower()}{ext}"

        success = self._download_first_available(info["urls"], dest)
        if not success:
            self.log(f"Failed to download {tool_name}. Opening vendor page.")
            self._open_vendor_page(tool_name)
            return

        self.log(f"Saved {tool_name} installer.")

    def _download_first_available(self, urls, dest):
        for url in urls:
            try:
                self._download_file(url, dest)
                if dest.exists() and dest.stat().st_size > 0:
                    return True
            except Exception as exc:
                self.log(f"Download failed: {url} ({exc})")
        return False

    def _download_file(self, url, dest):
        request = urllib.request.Request(
            url,
            headers={"User-Agent": f"{APP_NAME}/1.0"},
        )
        with urllib.request.urlopen(request, timeout=30) as response:
            total_header = response.getheader("Content-Length")
            total = int(total_header) if total_header and total_header.isdigit() else 0
            downloaded = 0
            last_logged = -1
            chunk_size = 256 * 1024
            with open(dest, "wb") as handle:
                while True:
                    chunk = response.read(chunk_size)
                    if not chunk:
                        break
                    handle.write(chunk)
                    downloaded += len(chunk)
                    if total:
                        percent = int((downloaded / total) * 100)
                        bucket = percent // 10
                        if bucket > last_logged:
                            last_logged = bucket
                            self.log(f"Downloading {dest.name}: {bucket * 10}%")

    def _ensure_executable(self):
        adb_path, fastboot_path = platform_tools_paths()
        for tool in (adb_path, fastboot_path):
            if tool.exists():
                tool.chmod(tool.stat().st_mode | 0o111)

    def refresh_devices(self):
        self._run_in_thread(self._refresh_devices)

    def _refresh_devices(self):
        adb_path, fastboot_path = platform_tools_paths()
        adb_out = self._run_cmd([str(adb_path), "devices"]) if adb_path.exists() else ""
        fastboot_out = (
            self._run_cmd([str(fastboot_path), "devices"]) if fastboot_path.exists() else ""
        )

        adb_status = "No device" if "\tdevice" not in adb_out else "Device connected"
        fastboot_status = (
            "No device" if not fastboot_out.strip() else "Device connected"
        )

        self.after(0, self._set_device_status, adb_status, fastboot_status)

        if not adb_path.exists() or not fastboot_path.exists():
            self.log("Platform-tools not installed. Download them in Setup.")
        else:
            self.log("Refreshed device status.")

    def _set_device_status(self, adb_status, fastboot_status):
        self.adb_status.configure(text=adb_status)
        self.fastboot_status.configure(text=fastboot_status)

    def reboot_bootloader(self):
        self._run_in_thread(self._adb_command, "reboot", "bootloader")

    def reboot_system(self):
        self._run_in_thread(self._adb_command, "reboot")

    def fastboot_reboot(self):
        self._run_in_thread(self._fastboot_command, "reboot")

    def fastboot_wipe(self):
        if not messagebox.askyesno(
            APP_NAME,
            "This will wipe user data. Continue?",
        ):
            return
        self._run_in_thread(self._fastboot_command, "-w")

    def flash_selected(self):
        selections = {}
        for key, entry in self.flash_entries.items():
            value = entry.get().strip()
            if value:
                selections[key] = value

        if not selections:
            messagebox.showinfo(APP_NAME, "Select at least one image to flash.")
            return

        self._run_in_thread(self._flash_images, selections)

    def _flash_images(self, selections):
        for partition, image_path in selections.items():
            self.log(f"Flashing {partition} from {image_path}...")
            self._fastboot_command("flash", partition, image_path)

        self.log("Flash sequence complete.")

    def _adb_command(self, *args):
        adb_path, _ = platform_tools_paths()
        if not adb_path.exists():
            self.log("ADB not found. Download platform-tools first.")
            return
        self._run_cmd([str(adb_path), *args])

    def _fastboot_command(self, *args):
        _, fastboot_path = platform_tools_paths()
        if not fastboot_path.exists():
            self.log("Fastboot not found. Download platform-tools first.")
            return
        self._run_cmd([str(fastboot_path), *args])

    def _run_cmd(self, cmd):
        self.log(f"Running: {' '.join(cmd)}")
        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                check=False,
            )
        except FileNotFoundError:
            self.log("Command not found.")
            return ""

        output = (result.stdout or "") + (result.stderr or "")
        output = output.strip()
        if output:
            self.log(output)
        return output


if __name__ == "__main__":
    ensure_dirs()
    app = PhoneFlasherApp()
    if not is_macos():
        messagebox.showwarning(
            APP_NAME,
            "This app is designed for macOS. Some features may not work on this OS.",
        )
    app.mainloop()
