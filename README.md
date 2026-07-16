[简体中文](./README_zh.md) | **English**

# Swipe_Animation

A software page-turn animation patch for KOReader that provides a smooth "wipe / erase and reveal" effect.

This patch brings fluid page turn animations to devices that lack native hardware support (or as an enhanced experience on supported devices).

## Features

* Smooth and faster page-turn animations
* Reduces screen flickering during page turns
* Customizable full refresh interval to control ghosting
  *(Automatic refresh on chapter changes and image pages is currently not supported.)*
* Supports page-turn gestures in all directions
* Improved experience in Night Mode
* **New:** MTK device support (Kobo, Kindle 2022 and newer)
* **New:** Page-turn animation support for fixed-layout formats such as PDF, DjVu, and CBZ
* **New:** Adjustable animation delay (in milliseconds) for both portrait and landscape orientations through
  **Settings (⚙) → Gesture Manager → Page Turn Animation Settings**, eliminating the need to edit Lua files manually
* **New:** Customizable refresh mode with three options: **UI**, **Partial**, and **Fast**
---
## Installation

> **Important:** Back up your `koreader` directory before installing.

### Kindle / Kobo (Linux Version)
1. Connect your device to your computer via USB.
2. **Back up** your existing `koreader` folder.
3. Copy the `ffi`, `frontend`, and `patches` folders from the extracted package into your device's `koreader` directory, and **merge/overwrite** the existing folders.
   **Do not delete the original folders.**
   * Typical path: `D:\.adds\koreader\`
   * **Note:** If your device already supports native hardware page-turn animations and you only want to enable native animations for PDF files, simply copy the `patches` folder into the `koreader` directory instead of installing the full patch.
4. Safely eject the device and restart KOReader.
5. Enable the animation:
   * Open any book.
   * Go to **Settings (⚙) → Gesture Manager → Page Turning**.
   * Enable **Page Turn Animation**.
6. *(Optional)* Adjust the animation delay:
   * Open **Settings (⚙) → Gesture Manager → Page Turn Animation Settings**.
   * Configure separate animation delays (ms) for portrait and landscape mode.
---
### Android E-Ink Devices
Applicable to Android versions of KOReader running on devices such as **BOOX, iReader, Hanvon, Xiaomi**, and other Android-based e-readers.
1. Connect your Android device.
2. From the extracted package, open the **Android Version** (`android_version`) folder.
3. Copy the `patches` folder into your device's `koreader` directory and merge it with the existing files.
   * If the `patches` folder does not exist, it will be created automatically.
4. Restart KOReader.
---

## Supported Devices
* **Fully tested:** Kobo devices, Kindle devices (including KV, KO, and KPW series), and most Linux-based e-ink devices running KOReader.
* **Android:** Android devices are **currently not supported**, as the animation performance is not satisfactory on the Android platform.

---

## FAQ

### Q: KOReader crashes after installing the patch.

Restore the original files from your backup.

Common causes include:

1. Your KOReader version is outdated. Update KOReader to the latest version and reinstall the patch.
2. You are using macOS to copy the files. Restore the original files first, delete the corresponding original files manually, and then copy the patched files again.
3. The installation was not performed correctly. Restore your backup and repeat the installation steps carefully.

---

### Q: The "Page Turn Animation" option appears, but nothing happens.

Update KOReader to the latest version and reinstall the patch.

---

### Q: The screen flashes black and white on every page turn.

Adjust the **Full Refresh Interval** under:

**Settings → Screen → E-Ink Settings → Full Refresh Interval**

---

## Credits

* Original author: `xhs:5699990012`
* Improved version: **nuku**
* v3.x optimization and MTK support:

  * **Echoes**
  * **小红薯6809667F**
  * **斯普特尼克的漫游**

---

## License

This project is licensed under **GPLv3**, following the same license as KOReader.
