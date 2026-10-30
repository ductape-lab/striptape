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

*(Note: because I don't give Apple \$99/year for a developer certificate, macOS Gatekeeper will block opening prebuilt downloads by default. You can run `xattr -cr /Applications/striptape.app` in Terminal to clear the quarantine flag, but honestly building it from source just makes more sense: it takes 5 seconds, ad-hoc signs locally on your Mac, and bypasses Gatekeeper entirely).*

### build from source (macOS 13+)

Building it locally is recommended:
```bash
git clone https://github.com/ductape-lab/striptape.git
cd striptape
./build_app.sh
open build/striptape.app
```

Everything here is local.

---

if something saved you a headache you may buy me a drink: [ductape.gumroad.com](https://ductape.gumroad.com/)
