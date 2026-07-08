# Swipe_Animation

A software page-turn animation patch for KOReader that provides a smooth "wipe / erase and reveal" effect.

This patch brings fluid page turn animations to devices that lack native hardware support (or as an enhanced experience on supported devices).

## Features (v3.5)

- Smoother and faster page turn animation
- Reduced screen jitter during transitions
- Customizable full refresh rate to control ghosting
- Supports swipes in all directions
- Improved experience in night mode
- Added support for MTK devices (Kobo and Kindle 2022+)
  - **Note**: On Kindle 2022 and later, animation support is partial (only one direction works)

This project is based on the original work by `xhs:5699990012`, further improved by `nuku`, and optimized by **Echoes**.

## Installation

### Requirements
- KOReader installed on your device
- USB file access to the device
- Recommended: Latest version of KOReader

### Steps

1. Connect your device to a computer via USB.
2. **Backup** your existing `koreader` folder first.
3. Copy the `ffi` and `frontend` folders from this repository into your device's `koreader` directory, overwriting existing files.
   - Typical path: `D:\.adds\koreader\` (path varies by device)
4. Safely eject the device and restart KOReader.
5. Enable the animation:
   - Open any document → Tap the top menu → **Settings (gear icon)** → **Taps and gestures** → **Page turns**
   - Check **"Page turn animation"**

## Recommended Settings

If pages flash black/white on every turn:
- Go to **Settings → Screen → E-ink settings → Full refresh rate**
- Increase the value to reduce flashing frequency.

## Supported Devices

- **Well tested**: Kobo series and pre-2022 Kindle devices (including KO and KPW series)
- **Should work**: Most Linux-based e-readers running KOReader
- **Partial support**: Kindle 2022 and newer (MTK) — animation only works in one direction
- **Not supported**: Most Android e-ink devices

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
