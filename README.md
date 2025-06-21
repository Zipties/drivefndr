# drivefndr

**Map and locate drives on your SAS backplane from the terminal.**

## Overview

**drivefndr** is a Bash script for TrueNAS SCALE (or any Linux box) with a SAS expander backplane (tested on AIC 12G 4U24SAS3EOB). It instantly maps `/dev/sdX` device names to their physical enclosure slot, lets you look up drives by serial number or device label, and prints a clear ASCII slot map—no GUI required.

If you’ve ever wondered “which drive is `/dev/sdm`?” or needed to swap a failed disk without confusion, this tool is for you.

---

## Features

- **Lookup by Serial:**  
  Enter the last 4 digits of a serial (case-insensitive) to find its slot and device name.
- **Lookup by Label:**  
  Enter a Linux device (like `sdd`) to get serial and slot.
- **Graphical Slot Map:**  
  Prints a 24-bay ASCII grid: shows drive slot, device name, serial, and size (rounded to nearest TB).
- **Empty Slot Handling:**  
  Empty slots are shown as “EMPTY” for easy visual checks.
- **No Reboot or GUI Needed:**  
  All from a single terminal command. No web UI or browser.
- **Easily Customizable:**  
  The slot order is stored in a simple mapping array—change it for your chassis in seconds.
- **Automatic Enclosure Discovery:**  
  Auto-detects available enclosures on first run; lets you pick and remembers your choice. You can re-select from the menu at any time.
- **User-Configurable Slot Labels and Grid Size:**  
  Set grid size and custom slot display labels at the top of the script, matching any chassis or rack labeling.
- **Persistent Settings:**  
  Remembers enclosure and label preferences across runs in a local config file.


---

## Screenshot


![Termius_J6EwAYbO4q](https://github.com/user-attachments/assets/f2970bec-d61b-47ef-b336-728036abcc0d)

![Termius_bjqWBi6ocJ](https://github.com/user-attachments/assets/492a2a52-c2a4-41be-b399-9144eb4cf093)

---

## Requirements

- TrueNAS SCALE or any modern Linux (Debian/Ubuntu, etc)
- SAS HBA (tested with LSI SAS3008 in IT mode)
- Expander backplane (tested with AIC 12G 4U24SAS3EOB)
- Basic drive labels and/or serials readable by `sg_inq` and sysfs
- Bash, `sg_inq`, coreutils

---

## Usage

1. Copy `drivefndr.sh` to your NAS or server.
2. Make executable:
   ```bash
   chmod +x drivefndr.sh

## 🏁 Run `drivefndr` From Anywhere (Optional)

If your system is **read-only** (like TrueNAS SCALE), you can't symlink scripts into `/usr/local/bin`.
Instead, create a shell alias so you can call `drivefndr` globally:

### 1. Open your `.bashrc` (or `.profile`)
nano ~/.bashrc

### 2. Add this line at the end
alias drivefndr='/root/drivefndr.sh'
# (Update the path if your script is elsewhere!)

### 3. Reload your shell
source ~/.bashrc

### 4. Now you can run `drivefndr` from anywhere
drivefndr

**Note:**
Any changes you make to `/root/drivefndr.sh` take effect immediately.

