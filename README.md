# striptape 🩹

I hate downloading an image from the web only for it to be a `.webp` or `.avif` that Discord won't let me share. Or taking a screenshot on Mac and finding out it has GPS coordinates and camera bloat attached to it.

This is a tiny menu bar app to solve that.

### what it does

- sits in your menu bar (`🩹`)
- hover or click it, drop an image, or just hit `⌘V`
- strips all metadata (GPS location, EXIF, device info)
- converts weird web formats into a clean PNG or JPG
- copies it straight back to your clipboard so you can paste it into Discord

That's it.

### install

One line in Terminal:
```bash
curl -fsSL https://raw.githubusercontent.com/ductape-lab/striptape/main/install.sh | bash
```

Or download manually:  
👉 **[Download striptape v1.0.0](https://github.com/ductape-lab/striptape/releases/latest/download/striptape.zip)**

Unzip and move `striptape.app` to your Applications folder.

*(Note: because I don't give Apple \$99/year for a developer certificate, macOS Gatekeeper might block opening it the first time. Either **Right-click ➔ Open**, or run `xattr -cr /Applications/striptape.app` to clear the quarantine flag).*

Or build it from source (macOS 13+):
```bash
./build_app.sh
open build/striptape.app
```

Everything here is local. No tracking, no electron bloat, just native Swift.

---

if something saved you a headache you may buy me a drink: [ductape.gumroad.com](https://ductape.gumroad.com/)
