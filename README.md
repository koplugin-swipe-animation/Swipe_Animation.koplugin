[简体中文](./README%20_zh.md) | **English**

# Swipe_Animation

A software page-turn animation patch for KOReader that provides a smooth "wipe / erase and reveal" effect.

This patch brings fluid page turn animations to devices that lack native hardware support (or as an enhanced experience on supported devices).

## Features (v3.6)

- Smoother and faster page turn animation
- Reduced screen jitter during transitions
- Customizable full refresh rate to control ghosting
- Supports swipes in all directions
- Improved experience in night mode
- Added support for MTK devices (Kobo and Kindle 2022+)
  - **Note**: On Kindle 2022 and later, animation support is partial (only one direction works)
- **New in v3.6**: Page-turn animation support for fixed-layout formats (PDF, DjVu, CBZ)

This project is based on the original work by `xhs:5699990012`, further improved by `nuku`, and optimized by **Echoes**.

## Installation

### Kindle / Kobo Devices (Linux Version) Steps

1. Connect your device to a computer via USB.
2. **Backup** your existing `koreader` folder first.
3. Copy the `ffi`, `frontend`, and `patches` folders from the root of your downloaded (and unzipped) folder into your device's `koreader` directory, overwriting existing files.
   - Typical path: `D:\.adds\koreader\` (path varies by device)
   - **Special Note**: If your device already natively supports hardware page-turn animations and you do *not* want to use this patch's software wipe animation, but only want to enable native hardware page-turn animations for PDF files, you can choose to **only copy the `patches` folder** to your device's `koreader` directory.
4. Safely eject the device and restart KOReader.
5. Enable the animation:
   - Open any document → Tap the top menu → **Settings (gear icon)** → **Taps and gestures** → **Page turns**
   - Check **"Page turn animation"**

### Android E-ink Devices (Android Version) Steps

Suitable for Boox, Meebook, Hanvon, Xiaomi, and other devices running KOReader for Android:
1. Connect your Android device.
2. Copy the **`patches` folder inside the `android_version` folder** of your downloaded folder, and **overwrite copy** it directly into your device's `koreader` directory (if there is no `patches` folder in your `koreader` directory, it will be automatically created; if it exists, choose to merge/overwrite).
3. Restart KOReader for the changes to take effect.

## Recommended Settings

If pages flash black/white on every turn:
- Go to **Settings → Screen → E-ink settings → Full refresh rate**
- Increase the value to reduce flashing frequency.

## Supported Devices

- **Well tested**: Kobo series and pre-2022 Kindle devices (including KO and KPW series)
- **Should work**: Most Linux-based e-readers running KOReader
- **Partial support**: Kindle 2022 and newer (MTK) — animation only works in one direction
- **Android Support**: Supports most Android e-ink devices running KOReader (e.g., Boox, Meebook, Xiaomi, etc. using the Android Version steps above)

## Troubleshooting

**Q: The "Page turn animation" option shows up but does nothing?**  
A: Update KOReader to the latest version, then reinstall the patch.

**Q: Every page still has a black/white flash?**  
A: Adjust **Full refresh rate** in **Settings → Screen → E-ink settings**.

**Q: Kindle 2022 only has animation in one direction?**  
A: This is expected behavior due to current partial MTK support.

## Credits

- Original author: `xhs:5699990012`
- KPW4 improvements: `nuku`
- Further optimizations & MTK support (v3.x): **Echoes、小红薯6809667F、斯普特尼克的漫游**

## License

This patch follows the same license as KOReader (GPLv3).

---

**Warning**: Always back up your `koreader` folder before installing any patches.
