[简体中文](./README.md) | **English**

# Swipe_Animation

A software page-turn animation patch for KOReader that provides a smooth "wipe / erase and reveal" effect.

This patch brings fluid page turn animations to devices that lack native hardware support (or as an enhanced experience on supported devices).

## Features

* Smooth and faster page-turn animations
* Reduces screen flickering during page turns
* Customizable refresh interval 
* Supports page-turn gestures in all directions
* Improved experience in Night Mode
* **New:** MTK device support (Kobo, Kindle 2022 and newer)
* **New:** Page-turn animation support for fixed-layout formats such as PDF, DjVu, and CBZ
* **New:** Adjustable animation delay (in milliseconds) for both portrait and landscape orientations through
  **Settings (⚙) → Gesture Manager → Swipe Animation Settings**, eliminating the need to edit Lua files manually
* **New:** Customizable refresh mode with two options: **UI**, **Fast**
* **New:** Mild Global Refresh option for an improved text-only reading experience.
---
## Installation

> **Important:** Back up your `koreader` directory before installing.

### Kindle / Kobo (Linux Version)
1. Connect your device to your computer via USB.
2. **Back up** your existing `koreader` folder.
3. Copy the `frontend` and `patches` folders from the extracted package into your device's `koreader` directory, and **merge/overwrite** the existing folders. No files under `ffi/` are overwritten.
   **Do not delete the original folders.**
   * Typical path: `D:\.adds\koreader\`
   * **Note:** If your device already supports native hardware page-turn animations and you only want to enable native animations for PDF files, simply copy the `patches` folder into the `koreader` directory instead of installing the full patch.
4. Safely eject the device and restart KOReader.
5. Enable the animation:
   * Open any book.
   * Go to **Settings (⚙) → Gesture Manager → Page turns**.
   * Enable **Page turn animations**.
6. *(Optional)* Adjust the animation delay:
   * Open **Settings (⚙) → Gesture Manager → Swipe Animation Settings**.
   * Configure separate animation delays (ms) for portrait and landscape mode. Long-press the option to view its description.
7. *(Optional)* Adjust global refresh mode:
   * Open **Settings (⚙) → Gesture Manager → Swipe Animation Settings**.
   * Enable or disable **Mild global refresh**. Long-press the option to view its description.
---

## Version Notes

The bundled `frontend/ui/uimanager.lua` is a snapshot of:

- KOReader master: `ac1416d2` (2026-08-04)

Files under `ffi/` are not overwritten; all framebuffer-related behavior is
provided by the patches in `patches/`.

After updating KOReader, `uimanager.lua` may not match the new upstream code.
Reinstall the patch (or re-merge the changes on top of the new KOReader) to avoid issues.
---

## Supported Devices
* **Fully tested:** Kobo devices, Kindle devices (including KV, KO, and KPW series), and most Linux-based e-ink devices running KOReader.
* **Android:** Android devices are **currently not supported**, as the animation performance is not satisfactory on the Android platform.
---
## Menu Structure
```
Settings (⚙)
├── Taps and gestures
│   ├── Page turns
│   │   └── ☑ Page turn animations
│   └── Swipe animation settings
│       ├── Swipe animation refresh mode
│       │   ├── ○ UI refresh
│       │   └── ○ Fast refresh 
│       ├── Portrait animation frame delay: ms
│       ├── Landscape animation frame delay: ms
│       └── ☑ Mild global refresh
└── Screen
    └── E-ink settings
        └── Full refresh rate
```
---

## FAQ

### Q: KOReader crashes after installing the patch.

Restore the original files from your backup.

Common causes include:

1. Your KOReader version is outdated. Update KOReader to the latest version and reinstall the patch.
2. You are using macOS to copy the files. Restore the original files first, delete the corresponding original files manually, and then copy the patched files again.
3. The installation was not performed correctly. Restore your backup and repeat the installation steps carefully.


### Q: The "Page turn animations" option doesn't appear/The "Page turn animations" option appears, but nothing happens.

Update KOReader to the latest version and reinstall the patch.


### Q: The screen flashes black and white on every page turn.

Adjust the **Full Refresh Rate** under:

**Settings → Screen → E-Ink Settings → Full Refresh Rate**


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
