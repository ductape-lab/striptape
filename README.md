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

Grab the ready-to-use app:  
👉 **[Download striptape v1.0.0](https://github.com/ductape-lab/striptape/releases/latest/download/striptape.zip)**

Unzip and drop `striptape.app` into your Applications folder.

Or build it from source (macOS 13+):
```bash
./build_app.sh
open build/striptape.app
```

Everything here is local.

---

if something saved you a headache you may buy me a drink: [ductape.gumroad.com](https://ductape.gumroad.com/)
