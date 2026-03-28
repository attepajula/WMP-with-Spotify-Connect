# WMZ Renderer — User Guide

WMZ Renderer is a Mac app that opens Windows Media Player skin files (`.wmz`) and displays them as interactive windows. It lets you click the skin's buttons, move its sliders, and see every interaction logged in real time.

---

## What is a .wmz file?

A `.wmz` file is a Windows Media Player skin — a ZIP archive containing a skin definition (`.wms`) and image assets. Thousands were created by WMP fans in the early 2000s. This app unpacks and renders them on macOS.

### Where to find skins

- [Wincustomize.com](https://www.wincustomize.com) — large archive, search "WMP skin"
- [https://wmpskinsarchive.neocities.org) — my favourite
Download the `.wmz` file directly — do not unzip it yourself.

---

## Running the app

The app is a command-line binary with a full graphical UI. Open Terminal and run:

```
/path/to/WMZRenderer
```

### Default skin

On launch the app looks for `Alienware_Darkstar_WMP11.wmz` in the same directory as the source files (the project root). If found, it loads automatically. If not found, an open file panel appears instead.

**To use a different default skin:** replace `Alienware_Darkstar_WMP11.wmz` in the project root with your own `.wmz` file and update the filename in `Sources/AppDelegate.swift`:

```swift
.appendingPathComponent("YourSkin.wmz")
```

Then rebuild:

```bash
swiftc \
  -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk \
  -target arm64-apple-macos13 \
  -framework Cocoa \
  Sources/*.swift \
  -o .build/WMZRenderer
```

To always show the open panel instead, remove the default-skin block and restore `openFile(nil)`.

---

## Opening a skin

1. Use **File → Open WMZ…** (⌘O) to open the file panel.
2. Navigate to your `.wmz` file and click **Open**.
3. The skin unpacks automatically. The skin window replaces the current one.

---

## The skin window

The skin renders as a **borderless window** — no title bar, no traffic lights. The window shape matches the skin exactly.

- **Drag** anywhere on the skin background to move the window.
- **⌘Q** to quit.
- **File → Open WMZ…** (⌘O) to load a different skin without quitting.
- The close button *inside the skin* (if the skin has one) closes the window.

---

## Interacting with the skin

### Buttons

Click any button on the skin. The button will visually press (switching to its "down" image) and the action is logged. Common actions:

| Action | What it does now |
|---|---|
| `play` | Logged; switches to pause button |
| `pause` / `stop` | Logged; switches back to play button |
| `next` / `previous` | Logged |
| `mute` | Logged |
| `close` | Closes the skin window |
| `minimize` | Minimizes the skin window |
| `shuffle` / `repeat` | Logged |

Tooltips appear on hover for buttons that declare them in the skin.

### Sliders

Drag any slider to move it. The action name and current value are logged. Sliders are rendered using the skin's own sprite sheet — they look and feel native to the skin.

Most skins have two sliders:
- **Seek bar** — track position
- **Volume** — output level

Neither controls actual audio yet; that comes in a future update.

### Text labels

Static text defined in the skin is shown as-is. Fields that WMP would fill at runtime (current track title, elapsed time, etc.) are blank for now.

---

## Configure mode (Cmd+D)

Press **⌘D** to toggle configure mode. All detected button and slider regions are highlighted with coloured overlays so you can verify hit detection:

- **Blue** — button region
- **Orange** — slider region

Press **⌘D** again to return to normal.

---

## The Action Log

Every event is logged with an ISO 8601 timestamp. The log is written to:

```
~/Documents/wmz-actions.log
```

Follow it live in Terminal:

```bash
tail -f ~/Documents/wmz-actions.log
```

---

## Troubleshooting

### The skin loads but looks wrong or has missing pieces

Compatibility varies between skins. The renderer is developed and tested against the **Alienware Darkstar** skin. Other skins may use WMS features that aren't implemented yet (multiple views, equalizer panels, video elements, etc.).

### "No .wms skin definition file found in archive"

The `.wmz` may be incomplete or corrupted. Try a different skin. Also check it isn't a `.wsz` (Winamp skin) — those look similar but are a different format.

### The skin window appears but is mostly blank

Image filenames in the `.wms` don't match the files in the archive (common with older or hand-edited skins). Check the Action Log for messages like `can't load 'background.bmp'`. The app tries a case-insensitive match but does not search subdirectories.

### Buttons are in the wrong place or missing

The skin uses a `mappingImage` for button hit regions. If that file is missing or the colours don't match, buttons won't appear. Check the log for "no pixels for color" messages.

### The window is off-screen after loading

Some skins declare very large dimensions. The window spawns centered but may extend beyond the screen. Drag it by clicking anywhere on the skin background.

---

## Known limitations (current version)

- **No audio playback.** Buttons log their actions only.
- **Default skin is hardcoded.** Changing the default requires editing source and rebuilding (see above).
- **Only the first view is rendered.** Skins with mini-player or equalizer views show only the main view.
- **No hover images.** The hover state is parsed but not displayed.
- **Text fields are static.** Dynamic fields remain blank.
- **Compatibility varies.** The renderer is optimised for the Alienware Darkstar skin; other skins may render incorrectly.

---

## What's coming

**Next update — Local Playback**
Drag an audio file onto the skin to start playback. Transport buttons will control AVFoundation. Seek and volume sliders will work. Track metadata will populate text labels.

**After that — Spotify Connect**
Log in with Spotify and the skin will control your active Spotify session on any device. Album art, track name, artist, and playback position will update in real time inside the skin.
