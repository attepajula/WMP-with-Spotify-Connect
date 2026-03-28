# WMZ Renderer — User Guide

WMZ Renderer is a Mac app that opens Windows Media Player skin files (`.wmz`) and displays them as interactive windows. It lets you click the skin's buttons, move its sliders, and see every interaction logged in real time.

---

## What is a .wmz file?

A `.wmz` file is a Windows Media Player skin — a ZIP archive containing a skin definition (`.wms`) and image assets. Thousands were created by WMP fans in the early 2000s. This app unpacks and renders them on macOS.

### Where to find skins

- [Wincustomize.com](https://www.wincustomize.com) — large archive, search "WMP skin"
- [DeviantArt](https://www.deviantart.com) — search "winamp wmz" or "wmp skin"
- [The Skins Factory](https://www.theskinsfactory.com) — commercial-quality skins, many free
- Older Microsoft WMP skin gallery archives (various fan-preservation sites)

Download the `.wmz` file directly — do not unzip it yourself.

---

## Running the app

The app is a command-line binary with a full graphical UI. Open Terminal and run:

```
/path/to/WMZRenderer
```

Two windows open immediately:

| Window | Purpose |
|---|---|
| **Action Log** | Shows a live timestamped log of everything that happens |
| **Open file panel** | Lets you pick a `.wmz` file to load |

---

## Opening a skin

1. When the file panel appears, navigate to your `.wmz` file and click **Open**.
2. The skin unpacks automatically. A skin window opens, sized and styled exactly as the skin author intended.
3. To open a different skin, use **File → Open WMZ…** (⌘O) or relaunch the app.

If the panel is dismissed without selecting a file, use **File → Open WMZ…** from the menu bar to reopen it.

---

## Interacting with the skin

### Buttons

Click any button on the skin. The button will visually press (switching to its "down" image) and the action is logged. Common actions:

| Action | What it does now |
|---|---|
| `play` | Logged (playback not yet wired up) |
| `pause` / `stop` | Logged |
| `next` / `previous` | Logged |
| `mute` | Logged |
| `volume` | Logged |
| `close` | Closes the skin window |
| `minimize` | Minimizes the skin window |
| `shuffle` / `repeat` | Logged |

Tooltips appear on hover for buttons that declare them in the skin.

### Sliders

Drag any slider to move it. The action name and current value (0–100) are logged.

Most skins have two sliders:
- **Seek bar** — track position
- **Volume** — output level

Neither controls actual audio yet; that comes in a future update.

### Text labels

Static text (track name, artist, album, time) defined in the skin is shown as-is. Fields that WMP would fill at runtime (like current track title) are blank for now.

---

## The Action Log

The log window shows every event with an ISO 8601 timestamp:

```
[2026-03-28T14:22:01Z] WMZ Renderer started
[2026-03-28T14:22:04Z] Opening: ClassicWMP.wmz
[2026-03-28T14:22:04Z] Extracted ClassicWMP.wmz → /var/folders/.../wmz_A1B2C3/
[2026-03-28T14:22:04Z] Parsing: ClassicWMP.wms
[2026-03-28T14:22:04Z] Rendered 'main' 275×90 — 12 buttons, 2 sliders, 3 labels
[2026-03-28T14:22:09Z] Button: play
[2026-03-28T14:22:11Z] Slider 'seek': 34.50
```

The same log is written to a file that persists between sessions:

```
~/Documents/wmz-actions.log
```

Open it in any text editor or tail it in Terminal:

```bash
tail -f ~/Documents/wmz-actions.log
```

---

## Troubleshooting

### "No .wms skin definition file found in archive"

The `.wmz` you downloaded may be incomplete or corrupted. Try a different skin, or check that the file is actually a `.wmz` and not a `.wsz` (Winamp skin) or `.zip` with unrelated content.

### The skin window appears but is mostly blank

The skin's image files use filenames that don't match what the `.wms` file references (common with hand-edited or older skins). The log window will show lines like:

```
ButtonGroup skipped: can't load 'background.bmp'
```

The app already tries a case-insensitive match, but some skins store images in subdirectories not yet searched. This is a known limitation.

### Buttons are in the wrong place or missing

The skin uses a `mappingImage` for button hit regions. If that file is missing or uses a non-standard format, buttons won't be detected. Check the log for "no pixels for color" messages.

### The skin window is too large or partially off-screen

Some skins declare very large dimensions. Drag the window to reposition it. Resizing is not supported — the skin has fixed dimensions.

### The app quits when I close the skin window

This is intentional — closing the skin window does not quit the app. Only the Action Log window and the menu bar remain. Use **File → Open WMZ…** to load another skin, or quit with ⌘Q.

---

## Known limitations (current version)

- **No audio playback.** Buttons log their actions but don't play, pause, or skip anything yet.
- **Only the first view is rendered.** Skins with separate mini-player or equalizer views show only the main view.
- **No hover images.** Some skins have a third image state for mouse-over; it is parsed but not shown.
- **Sliders use the native macOS style.** Skin-defined track and thumb graphics are ignored.
- **Text fields are static.** Dynamic fields (current track, elapsed time) remain blank.
- **Shaped / transparent windows are not supported.** The skin always appears inside a standard title-bar window even if the skin was designed to be borderless.

---

## What's coming

**Next update — Local Playback**
Drag an audio file onto the skin to start playback. Transport buttons (play, pause, stop, next, previous) will control AVFoundation. Seek and volume sliders will work. Track metadata will populate text labels.

**After that — Spotify Connect**
Log in with Spotify and the skin will control your active Spotify session on any device. Album art, track name, artist, and playback position will update in real time inside the skin.
