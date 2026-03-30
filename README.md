# WMP with Spotify Connect

A Mac app that renders the **Alienware Darkstar** Windows Media Player skin and (eventually) controls Spotify Connect playback through it.

> **⚠️ Compatibility notice**
> This renderer is built and tested exclusively against the **Alienware Darkstar WMP11** skin by TheSkinsFactor.com. Other `.wmz` skins will likely render incorrectly or partially. Broader skin support is not a current goal.

---

## Current state

- Alienware Darkstar skin renders correctly — background, buttons, sliders, digit display
- Buttons are clickable (play/pause toggle works; all actions are logged)
- Volume and seek sliders are interactive with correct sprite-sheet animation
- Time digits display as `0:00` (static — no playback yet)
- Borderless window, draggable by clicking anywhere on the skin
- Minimize works; close button closes the window
- No audio playback yet — all transport actions are logged only

---

## Building

No Xcode required. Build with the command-line tools:

```bash
swiftc \
  -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk \
  -target arm64-apple-macos13 \
  -framework Cocoa \
  Sources/*.swift \
  -o .build/WMZRenderer
```

Run: `.build/WMZRenderer`

The app opens `Alienware_Darkstar_WMP11.wmz` from the project root automatically on launch.

---

## Controls

| Input | Action |
|---|---|
| Click skin buttons | Logged to console and `~/Documents/wmz-actions.log` |
| Drag volume / seek slider | Value logged |
| Click minimize button | Minimizes to Dock |
| Click close button | Closes window |
| ⌘O | Open a different `.wmz` file |
| ⌘D | Toggle configure mode (shows hit regions) |
| ⌘Q | Quit |

---

## What's next

**Local playback** — wire transport buttons to AVFoundation, update time digits and slider positions from playback state.

**Spotify Connect** — replace local playback with the Spotify Web API (PKCE flow). The skin controls an active Spotify session on any device.

---

## Skin credits

The Alienware Darkstar skin is © 2005 Alienware Corporation, created by [TheSkinsFactor.com](https://www.theskinsfactory.com). All rights reserved.

Other WMP skin libraries (not used here, for reference):
- [Wincustomize.com](https://www.wincustomize.com) — large community archive
- [Windows Media Player Skins ](Archivehttps://wmpskinsarchive.neocities.org) — personal favourite
