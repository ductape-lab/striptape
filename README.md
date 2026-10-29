# striptape 🩹

> A tiny, local macOS menu bar utility that strips metadata bloat and converts annoying web image formats so you can actually share them on Discord.

---

### The Annoyance

1. You download a meme or picture from the web and it arrives in `.webp` or `.avif` — Discord refuses to inline preview it or treats it like a weird file download.
2. You snap a screenshot on your Mac or take a photo, and it comes packed with EXIF metadata, camera device details, GPS coordinates, and color profile junk.

### The Fix

**striptape** sits in your macOS menu bar as a tiny bandage `🩹`:
- **Hover or click** the icon to open the dropzone.
- **Drag & drop** any image file or URL directly onto the menu bar icon or into the box.
- Or simply hit **⌘V** to paste whatever image you just copied.
- **striptape** immediately strips 100% of metadata (GPS, EXIF, camera tags, device info) and converts it to a clean, universal format (**PNG** or **JPG**).
- It **automatically copies the clean image back to your clipboard** — switch over to Discord and press **⌘V**. Done.
- You can also drag the cleaned thumbnail straight out into Discord, Slack, or Finder.

---

### Features

- **Format Conversion for Discord:**
  - `WEBP` ➔ Clean `PNG` / `JPG`
  - `AVIF` ➔ Clean `PNG` / `JPG`
  - `HEIC` ➔ Clean `PNG` / `JPG`
  - `TIFF` / Bloated `PNG` ➔ Stripped, optimized `PNG`
- **Zero Metadata:** Strips GPS coordinates, EXIF tags, camera serial numbers, user comments, and Apple-specific maker notes.
- **100% Local-first:** Built with native Swift & Apple ImageIO. Zero internet calls, zero telemetry, zero node/electron bloat (~600 KB total app size).
- **Smooth Menu Bar UX:**
  - Hover or click to open.
  - Direct drag-onto-menu-bar icon support.
  - Visual drag-out thumbnail.
  - Format toggle: `Auto` (PNG for transparency, JPG for large photos), `PNG`, or `JPG`.
  - One-click "Save to Downloads" or "Copy to Clipboard".

---

### Building & Running

Requirements: macOS 13.0+

```bash
# Build the native macOS app bundle
./build_app.sh

# Launch striptape
open build/striptape.app
```

To run test suite:
```bash
swift run test_runner
```

---

### Support

I *vibe* code to solve things that annoy me. NOT a software engineer.  
Everything here is local. Take what you want.

If this saved you a headache, you can buy me a drink:  
👉 [ductape.gumroad.com](https://ductape.gumroad.com/)

